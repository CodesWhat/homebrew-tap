#!/usr/bin/env bash
#
# Compares every cask's pinned version against the latest published release of
# the project that owns it, and fails if any of them have diverged.
#
# This is deliberately independent of HOW a cask gets updated. The mouthtype
# cask is pulled by a workflow in this repository; careerrat is frozen and
# deprecated; dilated, portwing, sockguard and idlescreen are committed here by
# their own projects' release tooling. If one of those pushes silently stops
# happening, nothing else in this repository notices, and the tap keeps serving
# an old version. This script is the check that notices.
#
# A deprecated cask is skipped from its deprecate! date onward, because it
# intentionally stops following upstream.
#
# The tap is stable-only, with one named exception mechanism: a token listed in
# audit_exceptions/github_prerelease_allowlist.json is compared against the
# latest release including pre-releases. That file is also what `brew audit`
# reads, so it is the single source of truth. Once an allowlisted project's
# latest release is stable, this script errors until the entry is removed.
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

# Tokens allowed to track GitHub pre-releases, read from the same JSON that
# `brew audit` uses. Prints one token per line.
ALLOWLIST_FILE="audit_exceptions/github_prerelease_allowlist.json"
if command -v jq >/dev/null 2>&1; then
  prerelease_allowlist() { jq -r 'keys[]' "$ALLOWLIST_FILE"; }
elif command -v python3 >/dev/null 2>&1; then
  prerelease_allowlist() {
    python3 -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1]))))' "$ALLOWLIST_FILE"
  }
else
  echo 'ERROR  jq or python3 is required to read the pre-release allowlist.' >&2
  exit 2
fi
allowlist=""
if [ -f "$ALLOWLIST_FILE" ]; then
  allowlist="$(prerelease_allowlist)" || {
    echo "ERROR  could not parse $ALLOWLIST_FILE" >&2
    exit 2
  }
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

  # Homebrew treats a cask as deprecated only from its deprecate! date, so
  # skip only once that date has arrived. ISO dates compare as strings.
  deprecated_on="$(sed -n 's/^[[:space:]]*deprecate![[:space:]]*date:[[:space:]]*"\([0-9-]*\)".*/\1/p' "$cask" | head -1)"
  if [ -n "$deprecated_on" ] && [ ! "$deprecated_on" \> "$(date -u +%Y-%m-%d)" ]; then
    printf 'skip   %-12s %s (deprecated %s, not compared)\n' "$token" "$pinned" "$deprecated_on"
    continue
  fi

  allow_pre=0
  if printf '%s\n' "$allowlist" | grep -Fxq -- "$token"; then
    allow_pre=1
  fi

  if [ "$allow_pre" -eq 1 ]; then
    release="$(gh release list --repo "$repo" --exclude-drafts --limit 1 \
      --json tagName,isPrerelease --jq '.[0] | select(. != null) | "\(.tagName) \(.isPrerelease)"' \
      2>/dev/null || true)"
    tag="${release% *}"
    is_pre="${release##* }"
    tag_re='^v?[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$'
    tag_desc='vX.Y.Z or vX.Y.Z-pre'
  else
    tag="$(gh release list --repo "$repo" --exclude-drafts --exclude-pre-releases \
      --limit 1 --json tagName --jq '.[0].tagName // empty' 2>/dev/null || true)"
    is_pre=""
    tag_re='^v?[0-9]+\.[0-9]+\.[0-9]+$'
    tag_desc='vX.Y.Z'
  fi
  if [ -z "$tag" ]; then
    printf 'ERROR  %-12s no published stable release found in %s\n' "$token" "$repo"
    status=1
    continue
  fi

  # Only a leading v is stripped, so a project that started tagging
  # "release-1.2.3" would report as permanent drift against a correctly pinned
  # cask. Name that as the tagging change it is, rather than blaming the cask.
  if ! printf '%s' "$tag" | grep -Eq "$tag_re"; then
    printf 'ERROR  %-12s %s latest tag %s is not %s; this check cannot compare it\n' \
      "$token" "$repo" "$tag" "$tag_desc"
    status=1
    continue
  fi

  latest="${tag#v}"
  if [ "$pinned" = "$latest" ]; then
    suffix=""
    [ "$allow_pre" -eq 1 ] && suffix=" (pre-release allowed)"
    printf 'ok     %-12s %s%s\n' "$token" "$pinned" "$suffix"
  else
    printf 'DRIFT  %-12s cask pins %s, %s latest is %s\n' "$token" "$pinned" "$repo" "$latest"
    status=1
  fi

  if [ "$allow_pre" -eq 1 ] && [ "$is_pre" != "true" ]; then
    printf 'ERROR  %-12s still in %s but its latest release is stable; remove the entry\n' \
      "$token" "$ALLOWLIST_FILE"
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
