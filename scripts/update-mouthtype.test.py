#!/usr/bin/env python3
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parent / "resolve-mouthtype-release.sh"
HELPER = SCRIPT.parent / "cask-version.sh"
EXPR_PATH = "repos/CodesWhat/mouthtype/releases?per_page=100"

# Stub gh: validates argv, then runs the real jq expression over each page file,
# one page per file, as `gh api --paginate --jq` does. A FAIL file fails the call.
GH_STUB = """#!/usr/bin/env bash
set -euo pipefail
[ "$#" -eq 5 ] || { echo "unexpected argc: $*" >&2; exit 2; }
[ "$1" = api ] && [ "$2" = --paginate ] && [ "$3" = "%s" ] && [ "$4" = --jq ] \\
  || { echo "unexpected gh call: $*" >&2; exit 2; }
if [ -e "$GH_FIXTURE_ROOT/FAIL" ]; then
  echo 'gh: HTTP 502 (stub)' >&2
  echo 'second line' >&2
  exit 1
fi
for page in "$GH_FIXTURE_ROOT"/pages/page-*.json; do
  [ -e "$page" ] || continue
  jq -r "$5" "$page"
done
""" % EXPR_PATH


def rel(tag, published="2026-01-01T00:00:00Z", draft=False, prerelease=False):
    return {"tag_name": tag, "draft": draft, "prerelease": prerelease,
            "published_at": published}


class ReleaseSelectionTests(unittest.TestCase):
    def resolve(self, pages, current, fail=False, cask=None):
        """pages: list of release lists, one per API page."""
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scripts").mkdir()
            shutil.copy(SCRIPT, root / "scripts/resolve-mouthtype-release.sh")
            shutil.copy(HELPER, root / "scripts/cask-version.sh")
            (root / "Casks").mkdir()
            (root / "Casks/mouthtype.rb").write_text(
                cask if cask is not None
                else f'cask "mouthtype" do\n  version "{current}"\nend\n')
            (root / "bin").mkdir()
            gh = root / "bin/gh"
            gh.write_text(GH_STUB)
            gh.chmod(0o755)
            (root / "pages").mkdir()
            for n, page in enumerate(pages, 1):
                (root / f"pages/page-{n}.json").write_text(json.dumps(page))
            if fail:
                (root / "FAIL").touch()
            output = root / "output"
            output.touch()
            env = dict(os.environ, PATH=f"{root / 'bin'}:{os.environ['PATH']}",
                       GH_FIXTURE_ROOT=str(root), GITHUB_OUTPUT=str(output))
            result = subprocess.run(["bash", "scripts/resolve-mouthtype-release.sh"],
                                    cwd=root, env=env, capture_output=True,
                                    text=True, timeout=10)
            return result, output.read_text()

    def test_equal_or_older_release_skips_generation(self):
        for release, current in [("v0.5.1", "0.6.0"), ("v0.6.0", "0.6.0"),
                                 ("v0.9.9", "0.10.0"), ("v1.9.9", "2.0.0"),
                                 ("v0.12.1", "0.12.2")]:
            with self.subTest(release=release, current=current):
                result, output = self.resolve([[rel(release)]], current)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(output, "version=\nchanged=false\n")

    def test_newer_release_proceeds_with_numeric_ordering(self):
        for release, current in [("v0.12.3", "0.12.2"), ("v0.10.0", "0.9.9"),
                                 ("v1.0.0", "0.99.99")]:
            with self.subTest(release=release, current=current):
                result, output = self.resolve([[rel(release)]], current)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(output, f"version={release[1:]}\n")

    def test_no_release_is_a_noop(self):
        result, output = self.resolve([[]], "0.12.2")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output, "version=\nchanged=false\n")

    def test_no_pages_at_all_is_a_noop(self):
        result, output = self.resolve([], "0.12.2")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output, "version=\nchanged=false\n")

    def test_malformed_release_or_current_version_fails_closed(self):
        for release, current in [("v0.12.3-rc.1", "0.12.2"), ("v0.12.3", "invalid"),
                                 ("v0.12.3", ""), ("release-1.2.3", "0.12.2")]:
            with self.subTest(release=release, current=current):
                result, output = self.resolve([[rel(release)]], current)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(output, "")

    def test_greatest_published_at_wins_over_listing_order(self):
        # v0.12.3 was created early as a draft and published later; the API
        # (and gh release list) order it after v0.12.4 by creation.
        pages = [[rel("v0.12.4", "2026-03-01T00:00:00Z"),
                  rel("v0.12.3", "2026-04-01T00:00:00Z")]]
        result, output = self.resolve(pages, "0.12.2")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output, "version=0.12.3\n")

    def test_stable_release_on_a_later_page_is_found(self):
        pages = [[rel("v0.13.0", "2026-05-01T00:00:00Z", prerelease=True)],
                 [rel("v0.12.3", "2026-04-01T00:00:00Z")]]
        result, output = self.resolve(pages, "0.12.2")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output, "version=0.12.3\n")

    def test_drafts_and_prereleases_are_ignored(self):
        pages = [[rel("v0.14.0", None, draft=True),
                  rel("v0.13.0", "2026-05-01T00:00:00Z", draft=True),
                  rel("v0.13.1-rc.1", "2026-05-02T00:00:00Z", prerelease=True),
                  rel("v0.12.2", "2026-02-01T00:00:00Z")]]
        result, output = self.resolve(pages, "0.12.2")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output, "version=\nchanged=false\n")

    def test_only_drafts_and_prereleases_is_a_noop(self):
        pages = [[rel("v0.14.0", None, draft=True),
                  rel("v0.13.1-rc.1", "2026-05-02T00:00:00Z", prerelease=True)]]
        result, output = self.resolve(pages, "0.12.2")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(output, "version=\nchanged=false\n")

    def test_api_failure_fails_the_step(self):
        result, output = self.resolve([[rel("v0.12.3")]], "0.12.2", fail=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn("::error::", result.stdout + result.stderr)
        self.assertIn("HTTP 502", result.stdout + result.stderr)
        self.assertNotIn("version=0", output)
        self.assertNotIn("changed=false", output)

    def test_header_comment_does_not_shadow_version_stanza(self):
        for comment, current, release, want in [
                ("9.9.9", "0.12.2", "v0.12.3", "version=0.12.3\n"),
                ("0.0.1", "0.12.3", "v0.12.3", "version=\nchanged=false\n")]:
            with self.subTest(comment=comment):
                cask = (f'# Generated for 1.0, previously version "{comment}"\n'
                        f'# see {comment}\n'
                        f'cask "mouthtype" do\n  version "{current}"\nend\n')
                result, output = self.resolve([[rel(release)]], current, cask=cask)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(output, want)


if __name__ == "__main__":
    unittest.main()
