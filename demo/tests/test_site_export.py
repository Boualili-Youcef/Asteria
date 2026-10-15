"""The public export must reject unsafe output before invoking Node."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class SiteExportSafetyTests(unittest.TestCase):
    def invoke(self, target):
        return subprocess.run(['python3', str(ROOT/'demo/web/build.py'), '--output', str(target)], capture_output=True, text=True)

    def test_nonempty_output_is_never_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = Path(directory)/'personal.txt'
            marker.write_text('keep')
            result = self.invoke(directory)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('nonempty', result.stderr)
            self.assertEqual(marker.read_text(), 'keep')

    def test_repository_and_parents_are_rejected(self):
        for target in [ROOT, ROOT.parent]:
            result = self.invoke(target)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('unsafe output', result.stderr)

    def test_symlink_output_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)/'link'
            target.symlink_to(ROOT, target_is_directory=True)
            result = self.invoke(target)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('unsafe output', result.stderr)
