#!/usr/bin/env bash
# Tests scripts/open-cask-pr.sh with a stub gh on PATH. Run from the repo root.
set -uo pipefail

script="$PWD/scripts/open-cask-pr.sh"
failures=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/bin"

# Stub gh: logs argv to $GH_LOG. `pr list` prints $STUB_PR_LIST, `pr create`
# prints a PR URL, `workflow run cask-ci.yml` prints $STUB_DISPATCH_OUT, and
# `run watch` exits $STUB_WATCH_EXIT.
cat >"$tmp/bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "$*" >> "$GH_LOG"
case "$1 $2" in
  "pr list") [ -n "${STUB_PR_LIST:-}" ] && echo "$STUB_PR_LIST"; exit 0 ;;
  "pr create") echo "https://github.com/CodesWhat/homebrew-tap/pull/7"; exit 0 ;;
  "workflow run")
    [ "$3" = cask-ci.yml ] && printf '%s\n' "${STUB_DISPATCH_OUT-}"
    exit 0 ;;
  "run view")
    # Fails the first $STUB_VIEW_FAILS calls, like a run the API can't serve yet.
    n=$(($(cat "$GH_VIEW_COUNT" 2>/dev/null || echo 0) + 1))
    echo "$n" >"$GH_VIEW_COUNT"
    [ "$n" -le "${STUB_VIEW_FAILS:-0}" ] && { echo "HTTP 404: Not Found" >&2; exit 1; }
    exit 0 ;;
  "run watch") exit "${STUB_WATCH_EXIT:-0}" ;;
esac
exit 0
STUB
chmod +x "$tmp/bin/gh"

run_script() {
  : >"$tmp/gh.log"
  rm -f "$tmp/view.count"
  out="$(PATH="$tmp/bin:$PATH" GH_LOG="$tmp/gh.log" GH_VIEW_COUNT="$tmp/view.count" \
    OPEN_CASK_PR_POLL_SECONDS=0 OPEN_CASK_PR_VISIBLE_TRIES=3 bash "$script" mouthtype/v1.2.3 title body 2>&1)"
  rc=$?
}

expect() {
  local name="$1" cond="$2"
  if [ "$cond" = 1 ]; then
    echo "ok: $name"
  else
    echo "FAIL: $name"
    echo "$out"
    sed 's/^/  gh: /' "$tmp/gh.log"
    failures=$((failures + 1))
  fi
}

has() { grep -qxF -- "$1" "$tmp/gh.log" && echo 1 || echo 0; }
lacks() { grep -qF -- "$1" "$tmp/gh.log" && echo 0 || echo 1; }
rc_is() { [ "$rc" = "$1" ] && echo 1 || echo 0; }

url="https://github.com/CodesWhat/homebrew-tap/actions/runs/44912585826"
merge_call="workflow run cask-pr-merge.yml --ref main -f run_id=44912585826"

STUB_PR_LIST="" STUB_DISPATCH_OUT="$url" STUB_WATCH_EXIT=0 run_script
expect "new PR: exit 0" "$(rc_is 0)"
expect "new PR: created" "$(grep -q '^pr create ' "$tmp/gh.log" && echo 1 || echo 0)"
expect "new PR: cask-ci dispatched on the branch" "$(has 'workflow run cask-ci.yml --ref mouthtype/v1.2.3')"
expect "new PR: watched the run" "$(has 'run watch 44912585826 --exit-status --interval 10')"
expect "new PR: merger dispatched on main with the run id" "$(has "$merge_call")"
expect "new PR: never merges" "$(lacks 'pr merge')"

STUB_PR_LIST="12" STUB_DISPATCH_OUT="$url" STUB_WATCH_EXIT=0 run_script
expect "existing PR: exit 0" "$(rc_is 0)"
expect "existing PR: not created again" "$(lacks 'pr create')"
expect "existing PR: merger dispatched" "$(has "$merge_call")"

STUB_PR_LIST="12" STUB_DISPATCH_OUT="dispatched, no url" STUB_WATCH_EXIT=0 run_script
expect "no run id: exit 1" "$(rc_is 1)"
expect "no run id: no watch" "$(lacks 'run watch')"
expect "no run id: no merger dispatch" "$(lacks 'cask-pr-merge.yml')"

STUB_PR_LIST="12" STUB_DISPATCH_OUT="" STUB_WATCH_EXIT=0 run_script
expect "empty dispatch output: exit 1" "$(rc_is 1)"
expect "empty dispatch output: no merger dispatch" "$(lacks 'cask-pr-merge.yml')"

STUB_PR_LIST="12" STUB_DISPATCH_OUT="$url" STUB_VIEW_FAILS=2 run_script
expect "run 404s at first: exit 0" "$(rc_is 0)"
expect "run 404s at first: retried until visible" "$([ "$(grep -c '^run view 44912585826' "$tmp/gh.log")" = 3 ] && echo 1 || echo 0)"
expect "run 404s at first: merger dispatched" "$(has "$merge_call")"

STUB_PR_LIST="12" STUB_DISPATCH_OUT="$url" STUB_VIEW_FAILS=9 run_script
expect "run never visible: exit 1" "$(rc_is 1)"
expect "run never visible: says so" "$(grep -q 'cask-ci run 44912585826 never became visible; PR #12 left for a human.' <<<"$out" && echo 1 || echo 0)"
expect "run never visible: no watch" "$(lacks 'run watch')"
expect "run never visible: no merger dispatch" "$(lacks 'cask-pr-merge.yml')"

STUB_PR_LIST="12" STUB_DISPATCH_OUT="$url" STUB_WATCH_EXIT=1 run_script
expect "watch fails: exit 1" "$(rc_is 1)"
expect "watch fails: says so" "$(grep -q 'cask-ci run 44912585826 did not pass; PR #12 left for a human.' <<<"$out" && echo 1 || echo 0)"
expect "watch fails: no merger dispatch" "$(lacks 'cask-pr-merge.yml')"

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)"
  exit 1
fi
