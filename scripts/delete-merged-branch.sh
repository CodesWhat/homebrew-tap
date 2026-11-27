#!/usr/bin/env bash
# Deletes the head branch of a PR once it is confirmed MERGED. Usage:
# delete-merged-branch.sh <pr-number> <branch>. Needs GH_REPO and GH_TOKEN.
#
# GitHub's delete_branch_on_merge does not fire for merges made with the
# Actions GITHUB_TOKEN, so cask-pr-merge has to do it. This never fails the
# caller: the merge already happened, and a leftover branch is only clutter.
# It skips anything that is not a merged PR's own branch, and never main.
set -uo pipefail

pr="${1:-}"
branch="${2:-}"

if [ -z "$pr" ] || [ -z "$branch" ]; then
  echo "::warning::delete-merged-branch needs a PR number and a branch. Nothing deleted."
  exit 0
fi
if [ "$branch" = main ]; then
  echo "::warning::Refusing to delete main."
  exit 0
fi

state="$(gh pr view "$pr" --json state --jq .state 2>/dev/null || true)"
if [ "$state" != MERGED ]; then
  echo "::notice::PR #$pr is not confirmed merged (state: ${state:-unknown}). Leaving $branch."
  exit 0
fi

if out="$(gh api -X DELETE "repos/$GH_REPO/git/refs/heads/$branch" 2>&1)"; then
  echo "Deleted branch $branch."
elif grep -qE 'Reference does not exist|HTTP 404|HTTP 422' <<<"$out"; then
  echo "::notice::Branch $branch is already gone."
else
  echo "::warning::Could not delete branch $branch: $out"
fi
exit 0
