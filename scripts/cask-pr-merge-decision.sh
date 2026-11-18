#!/usr/bin/env bash
# Decides whether cask-pr-merge.yml may merge a pull request. Usage:
#   cask-pr-merge-decision.sh <head-ref> <pr-head-sha> <run-head-sha> \
#     <base-ref> <cross-repo:true|false> <draft:true|false>
# Reads one "<status> <filename>" line per changed file on stdin. Prints
# "merge" or "skip: <reason>" and exits 0 either way (2 on bad usage).
#
# The product is taken from the head ref: portwing-*, sockguard-* and
# mouthtype/v* may change only their own cask. Any other head gets generic
# cask-only eligibility. See cask-pr-eligible.sh for that rule.
set -euo pipefail

if [ "$#" -ne 6 ]; then
  echo "usage: cask-pr-merge-decision.sh <head-ref> <pr-head-sha> <run-head-sha> <base-ref> <cross-repo> <draft>" >&2
  exit 2
fi
head_ref="$1"
pr_sha="$2"
run_sha="$3"
base_ref="$4"
cross="$5"
draft="$6"
here="$(cd "$(dirname "$0")" && pwd)"

skip() {
  echo "skip: $1"
  exit 0
}

[ "$cross" = false ] || skip "the pull request is from a fork"
[ "$draft" = false ] || skip "the pull request is a draft"
[ "$base_ref" = main ] || skip "the base is '$base_ref', not main"
[ "$pr_sha" = "$run_sha" ] || skip "the head moved from $run_sha to $pr_sha"

only=()
case "$head_ref" in
  portwing-*) only=(--only portwing) ;;
  sockguard-*) only=(--only sockguard) ;;
  mouthtype/v*) only=(--only mouthtype) ;;
esac

if reason="$(bash "$here/cask-pr-eligible.sh" ${only[@]+"${only[@]}"})"; then
  echo merge
else
  skip "${reason#Not eligible: }"
fi
