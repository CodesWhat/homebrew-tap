#!/usr/bin/env bash
# Tests scripts/delete-merged-branch.sh with a stubbed gh. Run from the repo root.
set -uo pipefail

script="$PWD/scripts/delete-merged-branch.sh"
failures=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# The stub reads STUB_STATE for `gh pr view`, and for `gh api -X DELETE` prints
# STUB_DELETE_OUT and exits STUB_DELETE_RC. Every call is logged to calls.log.
mkdir "$tmp/bin"
cat >"$tmp/bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$STUB_LOG"
case "$1" in
  pr) echo "$STUB_STATE" ;;
  api) echo "$STUB_DELETE_OUT"; exit "${STUB_DELETE_RC:-0}" ;;
esac
STUB
chmod +x "$tmp/bin/gh"

# check <name> <state> <delete-rc> <delete-out> <branch> <want-delete:yes|no> <want-output-substring>
check() {
  local name="$1" state="$2" rc="$3" dout="$4" branch="$5" want_del="$6" want_out="$7" out calls=no code
  : >"$tmp/calls.log"
  out="$(PATH="$tmp/bin:$PATH" GH_REPO=o/r STUB_LOG="$tmp/calls.log" STUB_STATE="$state" \
    STUB_DELETE_RC="$rc" STUB_DELETE_OUT="$dout" bash "$script" 7 "$branch" 2>&1)"
  code=$?
  grep -q 'api -X DELETE' "$tmp/calls.log" && calls=yes
  if [ "$code" -ne 0 ] || [ "$calls" != "$([ "$want_del" = yes ] && echo yes || echo no)" ] ||
    ! grep -qF -- "$want_out" <<<"$out"; then
    echo "FAIL: $name (exit $code, deleted=$calls, out: $out)"
    failures=$((failures + 1))
  else
    echo "ok: $name"
  fi
}

check "merged, deleted" MERGED 0 "" bump/dilated-1.1.0 yes "Deleted branch bump/dilated-1.1.0"
check "slash branch passes through" MERGED 0 "" mouthtype/v0.12.3 yes "mouthtype/v0.12.3"
check "already deleted 422" MERGED 1 "gh: Reference does not exist (HTTP 422)" b yes "::notice::Branch b is already gone"
check "already deleted 404" MERGED 1 "gh: Not Found (HTTP 404)" b yes "::notice::Branch b is already gone"
check "other delete error warns, exits 0" MERGED 1 "gh: Forbidden (HTTP 403)" b yes "::warning::Could not delete branch b"
check "open PR untouched" OPEN 0 "" b no "::notice::PR #7 is not confirmed merged"
check "closed PR untouched" CLOSED 0 "" b no "not confirmed merged"
check "unknown state untouched" "" 0 "" b no "state: unknown"
check "never main" MERGED 0 "" main no "Refusing to delete main"

if [ "$(PATH="$tmp/bin:$PATH" bash "$script" 2>&1 >/dev/null; echo $?)" != 0 ]; then
  echo "FAIL: missing args should exit 0"
  failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)"
  exit 1
fi
echo "all passed"
