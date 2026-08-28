#!/usr/bin/env bash
#
# Compares every cask's pinned version against the latest published release of
# the project that owns it, and fails if any of them have diverged.
#
# This is deliberately independent of HOW a cask gets updated. Only the
# careerrat cask is pushed by a workflow in this repository; portwing,
# sockguard and idlescreen are committed here by their own projects' release
# tooling. If one of those pushes silently stops happening, nothing else in
# this repository notices, and the tap keeps serving an old version. This
# script is the check that notices.
#
# Usage:
#   bash scripts/check-cask-drift.sh
#
# Requires the GitHub CLI, authenticated. In CI that is GH_TOKEN; locally it is
# whatever `gh auth status` reports. Exits non-zero on any divergence so it can
# be used directly as a CI gate.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Fail on the prerequisite rather than on four confusing empty release lookups.
if ! command -v gh >/dev/null 2>&1; then
  echo 'ERROR  the GitHub CLI (gh) is required: https://cli.github.com' >&2
  exit 2
fi
if ! gh auth status >/dev/null 2>&1; then
  echo 'ERROR  gh is not authenticated. Run "gh auth login", or set GH_TOKEN.' >&2
  exit 2
fi

# Owning repository for each cask, when it is not simply CodesWhat/<cask>.
# Add an entry here if a cask token ever stops matching its repository name.
upstream_repo() {
  case "$1" in
    *) printf 'CodesWhat/%s' "$1" ;;
  esac
}

# The version stanza, with a version.csv suffix stripped. idlescreen pins
# "0.1.1,63" (version plus build number); only the part before the comma is
# the release version, and that is what the tag is cut from.
pinned_version() {
  sed -n 's/^[[:space:]]*version "\([^"]*\)".*/\1/p' "$1" | head -1 | cut -d, -f1
}

status=0
checked=0

for cask in Casks/*.rb; do
  [ -e "$cask" ] || continue
  token="$(basename "$cask" .rb)"
  repo="$(upstream_repo "$token")"
  checked=$((checked + 1))

  pinned="$(pinned_version "$cask")"
  if [ -z "$pinned" ]; then
    printf 'ERROR  %-12s no version stanza found in %s\n' "$token" "$cask"
    status=1
    continue
  fi

  tag="$(gh release list --repo "$repo" --exclude-drafts --exclude-pre-releases \
    --limit 1 --json tagName --jq '.[0].tagName // empty' 2>/dev/null || true)"
  if [ -z "$tag" ]; then
    printf 'ERROR  %-12s no published stable release found in %s\n' "$token" "$repo"
    status=1
    continue
  fi

  latest="${tag#v}"
  if [ "$pinned" = "$latest" ]; then
    printf 'ok     %-12s %s\n' "$token" "$pinned"
  else
    printf 'DRIFT  %-12s cask pins %s, %s latest is %s\n' "$token" "$pinned" "$repo" "$latest"
    status=1
  fi
done

if [ "$checked" -eq 0 ]; then
  echo 'ERROR  no casks found under Casks/; this script is in the wrong place.'
  exit 1
fi

if [ "$status" -ne 0 ]; then
  cat <<'EOS'

A cask no longer matches its upstream release. Do not hand-edit a generated
cask to fix this: the header of each file names the generator that owns it, and
the next release would overwrite the edit. Fix the release tooling in the
owning project so its cask push happens, then re-run this check.
EOS
fi

exit "$status"
