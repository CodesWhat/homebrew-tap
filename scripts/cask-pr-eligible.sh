#!/usr/bin/env bash
# Decides whether a pull request may be merged without review. Reads one
# "<status> <filename>" line per changed file on stdin. Exits 0 if the PR is
# eligible, 1 if not, and prints the reason either way.
#
# Input comes from scripts/cask-pr-files.jq, which validates every filename on
# the JSON side and emits "reject <reason>" for anything unsafe, so a filename
# cannot inject extra records. A "reject" line makes the PR ineligible here.
#
# With `--only <name>`, the only cask allowed is Casks/<name>.rb. Branches that
# a publisher pushes (portwing-1.2.3) may touch only that product's cask.
#
# Eligible means at least one file, every file is a top-level cask
# (Casks/<lowercase-name>.rb), and every file was added or modified. Removals
# and renames are left for a human.
set -euo pipefail

only=""
if [ "${1:-}" = "--only" ]; then
  only="${2:-}"
  if ! [[ "$only" =~ ^[a-z0-9-]+$ ]]; then
    echo "usage: cask-pr-eligible.sh [--only <cask-name>]" >&2
    exit 2
  fi
elif [ "$#" -ne 0 ]; then
  echo "usage: cask-pr-eligible.sh [--only <cask-name>]" >&2
  exit 2
fi

path_re='^Casks/[a-z0-9-]+\.rb$'
files=0

while IFS= read -r line || [ -n "$line" ]; do
  [ -n "$line" ] || continue
  if [ "${line%% *}" = reject ]; then
    echo "Not eligible: ${line#reject }"
    exit 1
  fi
  status="${line%% *}"
  name="${line#* }"
  if [ "$status" = "$line" ]; then
    echo "Not eligible: malformed input line '$line'"
    exit 1
  fi
  if ! [[ "$name" =~ $path_re ]]; then
    echo "Not eligible: '$name' is not a top-level cask file"
    exit 1
  fi
  if [ -n "$only" ] && [ "$name" != "Casks/$only.rb" ]; then
    echo "Not eligible: '$name' is not Casks/$only.rb"
    exit 1
  fi
  if [ "$status" != modified ] && [ "$status" != added ]; then
    echo "Not eligible: '$name' has status '$status', only modified or added is allowed"
    exit 1
  fi
  files=$((files + 1))
done

if [ "$files" -eq 0 ]; then
  echo "Not eligible: the pull request changes no files"
  exit 1
fi
echo "Eligible: $files cask file(s), all added or modified"
