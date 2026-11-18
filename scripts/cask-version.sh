#!/usr/bin/env bash
# Shared by check-cask-drift.sh and resolve-mouthtype-release.sh; source it,
# don't run it.

# The version stanza, with a version.csv suffix stripped. idlescreen pins
# "0.1.1,63" (version plus build number); only the part before the comma is
# the release version, and that is what the tag is cut from.
pinned_version() {
  sed -n 's/^[[:space:]]*version "\([^"]*\)".*/\1/p' "$1" | head -1 | cut -d, -f1
}
