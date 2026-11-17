#!/usr/bin/env python3
import os
from pathlib import Path
import subprocess
import tempfile
import textwrap
import unittest


WORKFLOW = Path(__file__).resolve().parents[1] / ".github/workflows/update-mouthtype-cask.yml"
STEP = WORKFLOW.read_text().split("      - name: Resolve the latest published mouthtype release\n", 1)[1]
SCRIPT = textwrap.dedent(STEP.split("        run: |\n", 1)[1].split("      - name:", 1)[0])


class ReleaseSelectionTests(unittest.TestCase):
    def resolve(self, release, current):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "Casks").mkdir()
            (root / "Casks/mouthtype.rb").write_text(f'cask "mouthtype" do\n  version "{current}"\nend\n')
            (root / "bin").mkdir()
            gh = root / "bin/gh"
            gh.write_text('#!/bin/sh\nprintf "%s" "$RELEASE_TAG"\n')
            gh.chmod(0o755)
            output = root / "output"
            output.touch()
            env = dict(os.environ, PATH=f"{root / 'bin'}:{os.environ['PATH']}",
                       RELEASE_TAG=release, GITHUB_OUTPUT=str(output))
            result = subprocess.run(["bash", "-c", SCRIPT], cwd=root, env=env,
                                    capture_output=True, text=True, timeout=10)
            return result, output.read_text()

    def test_equal_or_older_release_skips_generation(self):
        for release, current in [("v0.5.1", "0.6.0"), ("v0.6.0", "0.6.0"),
                                 ("v0.9.9", "0.10.0"), ("v1.9.9", "2.0.0"),
                                 ("v0.12.1", "0.12.2")]:
            with self.subTest(release=release, current=current):
                result, output = self.resolve(release, current)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(output, "version=\nchanged=false\n")

    def test_newer_release_proceeds_with_numeric_ordering(self):
        for release, current in [("v0.12.3", "0.12.2"), ("v0.10.0", "0.9.9"),
                                 ("v1.0.0", "0.99.99")]:
            with self.subTest(release=release, current=current):
                result, output = self.resolve(release, current)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(output, f"version={release[1:]}\n")

    def test_no_release_is_a_noop(self):
        result, output = self.resolve("", "0.12.2")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output, "version=\nchanged=false\n")

    def test_malformed_release_or_current_version_fails_closed(self):
        for release, current in [("v0.12.3-rc.1", "0.12.2"), ("v0.12.3", "invalid"),
                                 ("v0.12.3", "")]:
            with self.subTest(release=release, current=current):
                result, output = self.resolve(release, current)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(output, "")


if __name__ == "__main__":
    unittest.main()
