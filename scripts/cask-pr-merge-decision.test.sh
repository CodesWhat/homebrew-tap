#!/usr/bin/env bash
# Tests scripts/cask-pr-merge-decision.sh. Run from the repo root.
set -uo pipefail

script="scripts/cask-pr-merge-decision.sh"
failures=0

# check <name> <want-prefix> <files> <head-ref> <pr-sha> <run-sha> <base> <cross> <draft>
check() {
  local name="$1" want="$2" input="$3" out
  shift 3
  out="$(printf '%s' "$input" | bash "$script" "$@")"
  if [ "${out%%:*}" != "$want" ]; then
    echo "FAIL: $name (got '$out', wanted $want)"
    failures=$((failures + 1))
  else
    echo "ok: $name"
  fi
}

cask=$'modified Casks/portwing.rb\n'
check "moved head" skip "$cask" portwing-1.0.0 bbb aaa main false false
check "base not main" skip "$cask" portwing-1.0.0 aaa aaa evil false false
check "cross-repo" skip "$cask" portwing-1.0.0 aaa aaa main true false
check "draft" skip "$cask" portwing-1.0.0 aaa aaa main false true
check "portwing branch, own cask" merge "$cask" portwing-1.0.0 aaa aaa main false false
check "portwing branch touching sockguard cask" skip $'modified Casks/sockguard.rb\n' portwing-1.0.0 aaa aaa main false false
check "portwing branch touching a workflow" skip $'modified Casks/portwing.rb\nmodified .github/workflows/cask-ci.yml\n' portwing-1.0.0 aaa aaa main false false
check "removed cask" skip $'removed Casks/portwing.rb\n' portwing-1.0.0 aaa aaa main false false
check "generic head, cask-only change" merge $'modified Casks/dilated.rb\nadded Casks/other.rb\n' release/dilated aaa aaa main false false
check "mouthtype head, own cask" merge $'modified Casks/mouthtype.rb\n' mouthtype/v1.2.3 aaa aaa main false false
check "mouthtype head touching portwing" skip $'modified Casks/portwing.rb\n' mouthtype/v1.2.3 aaa aaa main false false
check "unknown prefix with non-cask file" skip $'modified Casks/dilated.rb\nmodified scripts/audit-casks.sh\n' feature/x aaa aaa main false false
check "empty change" skip '' feature/x aaa aaa main false false

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)"
  exit 1
fi
echo "all passed"
