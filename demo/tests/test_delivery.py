import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).absolute().parents[2]
spec = importlib.util.spec_from_file_location('promote', ROOT / 'demo/scripts/promote.py')
promote = importlib.util.module_from_spec(spec)
spec.loader.exec_module(promote)


class DeliveryTests(unittest.TestCase):
    def release(self):
        return {'schema': 1, 'commit': 'a' * 40, 'image': promote.IMAGE,
                'digest': 'sha256:' + 'b' * 64, 'run_id': '123'}

    def test_valid_immutable_release(self):
        self.assertEqual(promote.validate_release(self.release())['run_id'], '123')

    def test_failed_command_diagnostics_stay_in_private_operator_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'operator.jsonl'
            failed = subprocess.CompletedProcess(['helm'], 1, '', 'private diagnostic')
            with patch.dict(os.environ, {'ASTERIA_OPERATOR_LOG': str(path)}), \
                 patch.object(promote.subprocess, 'run', return_value=failed):
                with self.assertRaises(RuntimeError) as error:
                    promote.run(['helm', 'upgrade'])
            self.assertNotIn('private diagnostic', str(error.exception))
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            self.assertEqual(json.loads(path.read_text())['stderr'], 'private diagnostic')

    def test_operator_log_cannot_write_into_repository(self):
        with patch.dict(os.environ, {'ASTERIA_OPERATOR_LOG': str(ROOT / 'operator-forbidden.jsonl')}), \
             patch.object(promote.subprocess, 'run', return_value=subprocess.CompletedProcess(['helm'], 1, '', 'private')):
            with self.assertRaises(ValueError):
                promote.run(['helm', 'upgrade'])
        self.assertFalse((ROOT / 'operator-forbidden.jsonl').exists())

    def test_reject_wrong_repository_tag_injection_and_extra_fields(self):
        for field, value in [('image', 'ghcr.io/other/image'), ('digest', 'latest'),
                             ('digest', 'sha256:' + 'b' * 64 + ':m13'),
                             ('commit', 'main'), ('run_id', '../123'), ('secret', 'unexpected')]:
            with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                promote.validate_release({**self.release(), field: value})

    def test_helm_and_postdeploy_failures_restore_and_verify_previous_image(self):
        for fail_upgrade in (True, False):
            target = unittest.mock.Mock()
            target.h = ['helm']
            target.verify.side_effect = [['old-image-id']] if fail_upgrade else [RuntimeError('probe'), ['old-image-id']]
            with patch.object(promote, 'run', side_effect=[RuntimeError('upgrade'), ''] if fail_upgrade else ['', '']) as run:
                outcome, ids = promote.transact(target, ['helm', 'upgrade'], 4, 'previous', 'candidate')
            self.assertEqual(outcome, 'failed_then_rolled_back')
            self.assertEqual(ids, ['old-image-id'])
            self.assertIn('rollback', run.call_args_list[-1].args[0])
            target.verify.assert_called_with('previous')

    def test_failed_rollback_never_reports_success(self):
        target = unittest.mock.Mock()
        target.h = ['helm']
        with patch.object(promote, 'run', side_effect=RuntimeError('unreachable')):
            with self.assertRaises(RuntimeError):
                promote.transact(target, ['helm', 'upgrade'], 4, 'previous', 'candidate')

    def test_wrong_cluster_rejected_before_helm(self):
        system = json.dumps({'metadata': {'uid': 'wrong'}})
        demo = json.dumps({'metadata': {'uid': 'demo'}})
        with patch.object(promote, 'run', side_effect=[system, demo]) as run:
            with self.assertRaises(ValueError):
                promote.Target('explicit', 'expected', 'demo')
        self.assertTrue(all(c.args[0][0] == 'kubectl' for c in run.call_args_list))

    def test_operator_requires_the_stable_helm_version_used_in_live_validation(self):
        system = json.dumps({'metadata': {'uid': 'system'}})
        demo = json.dumps({'metadata': {'uid': 'demo', 'labels': {'asteria.io/purpose': 'demo-v1'}}})
        for version, accepted in [('v3.15.0-rc.2', False), ('v4.2.0', False), ('v3.19.0+g3d8990f', True)]:
            with self.subTest(version=version), patch.object(promote, 'run', side_effect=[system, demo, version]):
                if accepted:
                    promote.Target('explicit', 'system', 'demo')
                else:
                    with self.assertRaises(ValueError):
                        promote.Target('explicit', 'system', 'demo')

    def test_successful_legacy_ci_without_functional_gate_is_rejected(self):
        data = self.release()
        info = {'conclusion': 'success', 'head_sha': data['commit'],
                'path': '.github/workflows/orders-demo.yml',
                'repository': {'full_name': promote.REPOSITORY}}
        with patch.object(promote, 'run', side_effect=[json.dumps(info), json.dumps({'jobs': []})]):
            with self.assertRaises(ValueError):
                promote.verify_ci(data)

    @unittest.skipUnless(__import__('shutil').which('helm'), 'Helm is not installed on this test runner')
    def test_chart_preserves_default_and_renders_digest_without_tag(self):
        chart = str(ROOT / 'k8s/current-state/orders-api/chart')
        default = subprocess.check_output(['helm', 'template', 'orders-api', chart], text=True)
        self.assertIn('image: "docker.io/asteria/orders-api:m13"', default)
        digest = 'sha256:' + 'c' * 64
        rendered = subprocess.check_output(['helm', 'template', 'orders-demo', chart,
                        '-f', str(ROOT / 'demo/values.yaml'), '--set-string', 'image.digest=' + digest], text=True)
        self.assertIn(f'image: "{promote.IMAGE}@{digest}"', rendered)
        self.assertNotIn(digest + ':', rendered)
        self.assertNotIn('kind: Ingress', rendered)
        result = subprocess.run(['helm', 'template', 'orders-demo', chart,
                                  '--set-string', 'image.digest=bad'], capture_output=True)
        self.assertNotEqual(result.returncode, 0)


if __name__ == '__main__':
    unittest.main()
