import importlib.util
import json
from pathlib import Path
import subprocess
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
