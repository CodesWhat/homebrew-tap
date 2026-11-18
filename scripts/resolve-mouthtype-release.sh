#!/usr/bin/env bash
# Resolve the latest published mouthtype release and decide whether the cask
# needs regenerating. Writes version= (and changed=false when there is nothing
# to do) to $GITHUB_OUTPUT. Needs GH_TOKEN for gh.
set -euo pipefail

# Pick by published_at, not by listing order: `gh release list` orders by
# created_at, so a release created as a draft early and published later would
# be skipped forever. check-cask-drift.sh selects the same way. ISO-8601 UTC
# timestamps sort lexically.
errfile="$(mktemp)"
trap 'rm -f "$errfile"' EXIT
if ! releases="$(gh api --paginate "repos/CodesWhat/mouthtype/releases?per_page=100" \
  --jq '.[] | select(.draft == false and .prerelease == false and .published_at != null) | "\(.published_at) \(.tag_name)"' 2>"$errfile")"; then
  echo "::error::Could not list mouthtype releases: $(head -n 1 "$errfile")"
  exit 1
fi
tag="$(printf '%s\n' "$releases" | sed '/^$/d' | sort | tail -n 1 | cut -d' ' -f2-)"
if [ -z "$tag" ]; then
  echo "No published release found; nothing to do."
  echo "version=" >> "$GITHUB_OUTPUT"
  echo "changed=false" >> "$GITHUB_OUTPUT"
  exit 0
fi
version="${tag#v}"
if ! printf '%s' "$version" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$'; then
  echo "::error::Latest release tag '$tag' does not match vX.Y.Z"
  exit 1
fi
# Read the version stanza specifically. Matching the first three-part
# number anywhere in the file happens to work today only because
# `version` is the first such number; a comment mentioning a version
# above it would wedge this into a permanent, green no-op.
current="$(sed -n 's/^[[:space:]]*version "\([^"]*\)".*/\1/p' Casks/mouthtype.rb | head -1 | cut -d, -f1 || true)"
newer="$(python3 -c '
import re
import sys
release, current = sys.argv[1:]
if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", current):
    sys.exit("::error::Current cask version is missing or invalid")
released = tuple(map(int, release.split(".")))
pinned = tuple(map(int, current.split(".")))
print("true" if released > pinned else "false")
' "$version" "$current")"
if [ "$newer" != "true" ]; then
  echo "Release $version is not newer than cask $current; nothing to do."
  echo "version=" >> "$GITHUB_OUTPUT"
  echo "changed=false" >> "$GITHUB_OUTPUT"
  exit 0
fi
echo "version=$version" >> "$GITHUB_OUTPUT"
