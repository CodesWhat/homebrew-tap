#!/usr/bin/env bash
# Stages the main-branch ruleset as code (roadmap item HT-13d). Usage:
# apply-main-ruleset.sh [--apply]. Needs an authenticated gh with admin on the
# repo for --apply.
#
# rulesets/protect-main.json is the target ruleset: the live rules plus
# pull_request and the `audit every cask` required check. Requiring a PR turns
# off the direct pushes GoReleaser in sockguard and portwing still makes to
# main, so the target must not go live until those two stop publishing casks
# straight to main (they should open the cask PR instead).
#
# The default is a dry run: it reads the live ruleset and prints a normalized
# diff against the JSON, and changes nothing. With --apply it first refuses
# unless every precondition holds:
#   a. CodesWhat/sockguard main:app/.goreleaser.yaml has no homebrew_casks
#   b. CodesWhat/portwing main:.goreleaser.yml has no homebrew_casks
#   c. HOMEBREW_TAP_TOKEN is not a secret on sockguard or any portwing
#      environment (nothing is left that could push to main)
# Then it PUTs the JSON, re-reads the ruleset and fails if the normalized live
# copy, projected onto the file's shape, differs from the file.
#
# Env: REPO (default CodesWhat/homebrew-tap), RULESET_ID (default 20918191),
# RULESET_FILE (default rulesets/protect-main.json beside this script).
set -euo pipefail

repo="${REPO:-CodesWhat/homebrew-tap}"
id="${RULESET_ID:-20918191}"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
file="${RULESET_FILE:-$script_dir/../rulesets/protect-main.json}"
secret=HOMEBREW_TAP_TOKEN
endpoint="repos/$repo/rulesets/$id"

apply=0
case "${1:-}" in
  "") ;;
  --apply) apply=1 ;;
  *)
    echo "usage: apply-main-ruleset.sh [--apply]" >&2
    exit 2
    ;;
esac

# Only the fields we manage, with rules sorted so API ordering cannot show up
# as a difference.
normalize() {
  jq -S '{name, target, enforcement, conditions, bypass_actors, rules: (.rules | sort_by(.type))}'
}

# project <want.json>: narrows a normalized live ruleset to the target's shape.
# GitHub returns server-default parameter keys the target doesn't set, so for
# each rule that also exists in the target (matched by type) only the
# parameter keys the target sets are kept. A rule type present on one side
# only still differs, and so does a different value for a key the target sets.
project() {
  jq -S --slurpfile want "$1" '
    $want[0] as $w
    | .rules |= map(
        . as $r
        | ($w.rules | map(select(.type == $r.type)) | first) as $wr
        | if $wr == null then $r
          elif ($wr.parameters | type) != "object" then del(.parameters)
          elif ($r.parameters | type) != "object" then $r
          else .parameters |= with_entries(select(.key as $k | $wr.parameters | has($k)))
          end)'
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

normalize <"$file" >"$tmp/want.json"
gh api "$endpoint" | normalize | project "$tmp/want.json" >"$tmp/live.json"

if [ "$apply" -eq 0 ]; then
  echo "Dry run: live ruleset $id on $repo (-) versus $file (+)"
  if diff -u --label live --label target "$tmp/live.json" "$tmp/want.json"; then
    echo "No differences."
  fi
  exit 0
fi

refuse() {
  echo "Refusing to apply: $*" >&2
  exit 1
}

# check_no_casks <repo> <path> <label>: refuses if the file can't be read or
# still configures homebrew_casks.
check_no_casks() {
  local r="$1" path="$2" body
  body="$(gh api "repos/$r/contents/$path?ref=main" -H 'Accept: application/vnd.github.raw')" ||
    refuse "could not read $r main:$path"
  if grep -q 'homebrew_casks' <<<"$body"; then
    refuse "$r main:$path still has homebrew_casks"
  fi
}

check_no_casks CodesWhat/sockguard app/.goreleaser.yaml
check_no_casks CodesWhat/portwing .goreleaser.yml

names="$(gh secret list -R CodesWhat/sockguard --json name -q '.[].name')" ||
  refuse "could not list secrets on CodesWhat/sockguard"
if grep -qx "$secret" <<<"$names"; then
  refuse "$secret is still a secret on CodesWhat/sockguard"
fi

envs="$(gh api repos/CodesWhat/portwing/environments -q '.environments[].name')" ||
  refuse "could not list CodesWhat/portwing environments"
while IFS= read -r env; do
  [ -n "$env" ] || continue
  names="$(gh secret list -R CodesWhat/portwing --env "$env" --json name -q '.[].name')" ||
    refuse "could not list secrets in CodesWhat/portwing environment $env"
  if grep -qx "$secret" <<<"$names"; then
    refuse "$secret is still a secret in CodesWhat/portwing environment $env"
  fi
done <<<"$envs"

echo "Preconditions hold. Applying $file to ruleset $id on $repo."
gh api -X PUT "$endpoint" --input "$file" >/dev/null

gh api "$endpoint" | normalize | project "$tmp/want.json" >"$tmp/after.json"
if ! diff -u --label live-after-put --label target "$tmp/after.json" "$tmp/want.json"; then
  echo "Applied, but the live ruleset differs from $file." >&2
  exit 1
fi
echo "Applied and verified."
