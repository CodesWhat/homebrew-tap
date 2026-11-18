#!/usr/bin/env bash
# Opens (or reuses) a pull request into main for a pushed cask branch, runs
# cask-ci on the branch, and asks for squash auto-merge. Usage:
#   open-cask-pr.sh <branch> <title> <body>
# Env: GH_TOKEN, and GH_REPO (owner/name) when not run inside a checkout.
#
# A PR opened with GITHUB_TOKEN does not start workflows, but a dispatch does,
# and its check run lands on the branch head commit, which satisfies the
# required `audit every cask` check. Failing to enable auto-merge (for example
# while allow_auto_merge is off) is a warning that leaves the PR open.
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "usage: open-cask-pr.sh <branch> <title> <body>" >&2
  exit 2
fi
branch="$1"
title="$2"
body="$3"

pr="$(gh pr list --head "$branch" --base main --state open --json number --jq '.[0].number // empty')"
if [ -z "$pr" ]; then
  url="$(gh pr create --base main --head "$branch" --title "$title" --body "$body")"
  pr="${url##*/}"
fi
echo "Pull request #$pr is open for $branch."

gh workflow run cask-ci.yml --ref "$branch"

if ! gh pr merge "$pr" --auto --squash; then
  echo "::warning::Could not enable auto-merge on PR #$pr (is allow_auto_merge on?). The PR stays open for manual merge."
fi
