#!/usr/bin/env bash
# Tests scripts/cask-pr-eligible.sh. Run from the repo root.
set -uo pipefail

script="scripts/cask-pr-eligible.sh"
failures=0

check() {
  local name="$1" want="$2" input="$3" out rc
  shift 3
  out="$(printf '%s' "$input" | bash "$script" "$@")"
  rc=$?
  if [ "$rc" -ne "$want" ]; then
    echo "FAIL: $name (exit $rc, wanted $want): $out"
    failures=$((failures + 1))
  else
    echo "ok: $name"
  fi
}

check "one modified cask" 0 $'modified Casks/mouthtype.rb\n'
check "one added cask" 0 $'added Casks/new-thing.rb\n'
check "cask plus README" 1 $'modified Casks/mouthtype.rb\nmodified README.md\n'
check "workflow file" 1 $'modified .github/workflows/cask-ci.yml\n'
check "path traversal" 1 $'modified Casks/../x.rb\n'
check "nested directory" 1 $'modified Casks/sub/x.rb\n'
check "removed cask" 1 $'removed Casks/mouthtype.rb\n'
check "renamed cask" 1 $'renamed Casks/mouthtype.rb\n'
check "empty input" 1 ''
check "uppercase name" 1 $'modified Casks/Mouthtype.rb\n'
check "--only matching cask" 0 $'modified Casks/portwing.rb\n' --only portwing
check "--only another product's cask" 1 $'modified Casks/sockguard.rb\n' --only portwing
check "--only two casks" 1 $'modified Casks/portwing.rb\nmodified Casks/sockguard.rb\n' --only portwing
check "--only with README" 1 $'modified Casks/portwing.rb\nmodified README.md\n' --only portwing
check "--only prefix is not a match" 1 $'modified Casks/portwing-beta.rb\n' --only portwing

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)"
  exit 1
fi
echo "all passed"
