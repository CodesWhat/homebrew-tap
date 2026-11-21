#!/usr/bin/env bash
# Opens (or reuses) a pull request into main for a pushed cask branch and runs
# cask-ci on the branch. Usage:
#   open-cask-pr.sh <branch> <title> <body>
# Env: GH_TOKEN, and GH_REPO (owner/name) when not run inside a checkout.
#
# This never merges. A PR opened with GITHUB_TOKEN does not start workflows,
# but a dispatch does, and its check run lands on the branch head commit.
# GitHub also does not fire workflow_run for runs started with GITHUB_TOKEN, so
# cask-pr-merge.yml would never see that cask-ci run finish. Instead this waits
# for the dispatched run to pass, then dispatches cask-pr-merge.yml on main with
# the run id (workflow_dispatch is allowed from GITHUB_TOKEN). The merger
# re-reads the run from the API and applies every check itself.
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

dispatched="$(gh workflow run cask-ci.yml --ref "$branch")"
run_url="$(printf '%s\n' "$dispatched" | tail -n 1)"
run_id="${run_url##*/}"
case "$run_id" in
  '' | *[!0-9]*)
    echo "Could not read the cask-ci run id from: $dispatched" >&2
    exit 1
    ;;
esac
echo "Dispatched cask-ci run $run_id on $branch."

if ! gh run watch "$run_id" --exit-status --interval 10 >/dev/null; then
  echo "cask-ci run $run_id did not pass; PR #$pr left for a human." >&2
  exit 1
fi

gh workflow run cask-pr-merge.yml --ref main -f run_id="$run_id"
echo "Requested the merge check for PR #$pr from cask-ci run $run_id."
