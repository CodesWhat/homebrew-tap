#!/usr/bin/env bash
# Tests scripts/cask-pr-files.jq end to end: fixture compare JSON goes through
# the real filter, then the real merge decision script. Run from the repo root.
set -uo pipefail

failures=0

# files_json <status> <filename>... builds {"files":[...]} with one status.
files_json() {
  local status="$1"
  shift
  printf '%s\0' "$@" | jq -Rs --arg s "$status" \
    '{files: (split("\u0000")[:-1] | map({status: $s, filename: .}))}'
}

# decide <name> <want> <compare-json> [head-ref]
decide() {
  local name="$1" want="$2" json="$3" head="${4:-portwing-1.0.0}" out
  out="$(printf '%s' "$json" | jq -r -f scripts/cask-pr-files.jq |
    bash scripts/cask-pr-merge-decision.sh "$head" aaa aaa main false false)"
  if [ "${out%%:*}" != "$want" ]; then
    echo "FAIL: $name (got '$out', wanted $want)"
    failures=$((failures + 1))
  else
    echo "ok: $name"
  fi
}

decide "plain cask" merge "$(files_json modified Casks/portwing.rb)"
decide "literal newline forging a second record" skip \
  "$(files_json modified $'Casks/portwing.rb\nadded Casks/portwing.rb')"
decide "trailing newline" skip "$(files_json modified $'Casks/portwing.rb\n')"
decide "newline then non-cask" skip "$(files_json modified $'Casks/portwing.rb\nscripts/x.sh')"
decide "tab in name" skip "$(files_json modified $'Casks/port\twing.rb')"
decide "quote in name" skip "$(files_json modified 'Casks/port"wing.rb')"
decide "backslash in name" skip "$(files_json modified 'Casks/port\wing.rb')"
decide "space in name" skip "$(files_json modified 'Casks/port wing.rb')"
decide "nested cask path" skip "$(files_json modified Casks/sub/portwing.rb)"
decide "removed status" skip "$(files_json removed Casks/portwing.rb)"
decide "renamed status" skip "$(files_json renamed Casks/portwing.rb)"
decide "missing file list" skip '{}'

# 300 files is the compare API's cap and it gives no truncation flag, so a
# result of 300 may hide a 301st file such as scripts/backdoor.sh. 299 plain
# casks pass the filter, and 300 fail closed.
casks() {
  jq -n --argjson n "$1" \
    '{files: [range($n) | {status: "modified", filename: "Casks/c\(.).rb"}]}'
}
decide "299 casks (generic head)" merge "$(casks 299)" release/x
decide "300 casks fail closed" skip "$(casks 300)" release/x
decide "301 entries fail closed" skip "$(casks 301)" release/x

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)"
  exit 1
fi
echo "all passed"
