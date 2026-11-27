#!/usr/bin/env bash
# Tests scripts/apply-main-ruleset.sh with a stubbed gh. Run from the repo root.
set -uo pipefail

script="$PWD/scripts/apply-main-ruleset.sh"
target="$PWD/rulesets/protect-main.json"
failures=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# The live ruleset before the PUT is the current two-rule one, with the extra
# fields the real API returns. After a PUT the stub serves $tmp/after.json.
cat >"$tmp/live.json" <<'JSON'
{"id":20918191,"name":"protect-main","target":"branch","enforcement":"active","source":"x",
 "conditions":{"ref_name":{"exclude":[],"include":["~DEFAULT_BRANCH"]}},
 "bypass_actors":[],"rules":[{"type":"non_fast_forward"},{"type":"deletion"}]}
JSON

# Env knobs: STUB_SOCK_YAML, STUB_PORT_YAML (file contents), STUB_SOCK_FAIL /
# STUB_PORT_FAIL (fetch exits 1), STUB_SOCK_SECRETS, STUB_PORT_ENVS,
# STUB_ENV_SECRETS (names printed for any portwing env), STUB_AFTER (file).
mkdir "$tmp/bin"
cat >"$tmp/bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "$*" >>"$STUB_LOG"
case "$*" in
  "api -X PUT "*) touch "$STUB_STATE.put" ;;
  "api repos/o/r/rulesets/1")
    if [ -e "$STUB_STATE.put" ]; then cat "$STUB_AFTER"; else cat "$STUB_LIVE"; fi ;;
  "api repos/CodesWhat/sockguard/contents/app/.goreleaser.yaml?ref=main"*)
    [ -z "${STUB_SOCK_FAIL:-}" ] || exit 1
    printf '%s\n' "${STUB_SOCK_YAML:-builds: []}" ;;
  "api repos/CodesWhat/portwing/contents/.goreleaser.yml?ref=main"*)
    [ -z "${STUB_PORT_FAIL:-}" ] || exit 1
    printf '%s\n' "${STUB_PORT_YAML:-builds: []}" ;;
  "secret list -R CodesWhat/sockguard "*) printf '%s\n' ${STUB_SOCK_SECRETS:-OTHER} ;;
  "api repos/CodesWhat/portwing/environments"*) printf '%s\n' ${STUB_PORT_ENVS:-release} ;;
  "secret list -R CodesWhat/portwing --env "*) printf '%s\n' ${STUB_ENV_SECRETS:-OTHER} ;;
  *) echo "unstubbed: $*" >&2; exit 1 ;;
esac
STUB
chmod +x "$tmp/bin/gh"

# run <name> <want-exit> <want-put:yes|no> <want-output-substring> <args...>
# Environment knobs are passed through from the caller's environment.
run() {
  local name="$1" want_rc="$2" want_put="$3" want_out="$4" out rc put=no
  shift 4
  rm -f "$tmp/state.put"
  : >"$tmp/calls.log"
  out="$(PATH="$tmp/bin:$PATH" REPO=o/r RULESET_ID=1 RULESET_FILE="$target" \
    STUB_LOG="$tmp/calls.log" STUB_STATE="$tmp/state" STUB_LIVE="$tmp/live.json" \
    STUB_AFTER="${STUB_AFTER:-$tmp/after.json}" bash "$script" "$@" 2>&1)"
  rc=$?
  grep -q -- '-X PUT' "$tmp/calls.log" && put=yes
  if [ "$rc" -ne "$want_rc" ] || [ "$put" != "$want_put" ] || ! grep -qF -- "$want_out" <<<"$out"; then
    echo "FAIL: $name (exit $rc, put=$put, out: $out)"
    failures=$((failures + 1))
  else
    echo "ok: $name"
  fi
}

# What the live ruleset looks like once the target is applied.
jq '. + {id: 1, source: "x"}' "$target" >"$tmp/after.json"
# A PUT the API silently changes.
jq '.enforcement = "evaluate"' "$tmp/after.json" >"$tmp/after-bad.json"

run "dry run shows additions and does not PUT" 0 no '+      "type": "pull_request"'
run "dry run shows the status check" 0 no '+            "context": "audit every cask",'
run "bad flag" 2 no "usage:" --nope

run "apply happy path PUTs and verifies" 0 yes "Applied and verified." --apply

STUB_SOCK_YAML=$'homebrew_casks:\n  - name: sockguard' \
  run "apply refused: sockguard has homebrew_casks" 1 no "CodesWhat/sockguard main:app/.goreleaser.yaml still has homebrew_casks" --apply
STUB_PORT_YAML=$'homebrew_casks:\n  - name: portwing' \
  run "apply refused: portwing has homebrew_casks" 1 no "CodesWhat/portwing main:.goreleaser.yml still has homebrew_casks" --apply
STUB_SOCK_FAIL=1 \
  run "apply refused: sockguard config unreadable" 1 no "could not read CodesWhat/sockguard" --apply
STUB_PORT_FAIL=1 \
  run "apply refused: portwing config unreadable" 1 no "could not read CodesWhat/portwing" --apply
STUB_SOCK_SECRETS=$'OTHER\nHOMEBREW_TAP_TOKEN' \
  run "apply refused: secret on sockguard" 1 no "HOMEBREW_TAP_TOKEN is still a secret on CodesWhat/sockguard" --apply
STUB_PORT_ENVS=$'release\nprod' STUB_ENV_SECRETS=HOMEBREW_TAP_TOKEN \
  run "apply refused: secret in a portwing environment" 1 no "still a secret in CodesWhat/portwing environment release" --apply

STUB_AFTER="$tmp/after-bad.json" \
  run "verify mismatch after PUT fails" 1 yes "Applied, but the live ruleset differs" --apply

if [ "$failures" -ne 0 ]; then
  echo "$failures failure(s)"
  exit 1
fi
echo "all passed"
