import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).absolute().parents[2]
SCRIPT = ROOT / 'demo/scripts/prepare-bootstrap.py'


class BootstrapBoundaryTests(unittest.TestCase):
    def prepare(self, path):
        return subprocess.run([sys.executable, str(SCRIPT), '--output', str(path)],
                              capture_output=True, text=True)

    def test_secret_bundle_is_private_and_never_prints_password(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'bundle'
            result = self.prepare(output)
            self.assertEqual(result.returncode, 0)
            self.assertFalse(json.loads(result.stdout)['cluster_contacted'])
            self.assertEqual(output.stat().st_mode & 0o777, 0o700)
            for file in output.iterdir():
                self.assertEqual(file.stat().st_mode & 0o777, 0o600)
            items = json.loads((output / 'runtime.json').read_text())['items']
            password = next(x for x in items if x['kind'] == 'Secret')['stringData']['POSTGRES_PASSWORD']
            self.assertGreaterEqual(len(password), 32)
            self.assertNotIn(password, result.stdout + result.stderr)

    def test_repeated_preparation_refuses_to_rotate_existing_secret(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'bundle'
            self.assertEqual(self.prepare(output).returncode, 0)
            previous = (output / 'runtime.json').read_bytes()
            self.assertNotEqual(self.prepare(output).returncode, 0)
            self.assertEqual((output / 'runtime.json').read_bytes(), previous)

    def test_repository_output_and_symlink_to_repository_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            alias = Path(directory) / 'repo'
            alias.symlink_to(ROOT, target_is_directory=True)
            for target in [ROOT, alias]:
                self.assertNotEqual(self.prepare(target).returncode, 0)


if __name__ == '__main__':
    unittest.main()
