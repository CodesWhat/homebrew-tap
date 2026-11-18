#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/repo/scripts" "$fixture/repo/Casks" "$fixture/user-config/homebrew"
cp "$script_dir/audit-casks.sh" "$fixture/repo/scripts/audit-casks.sh"
printf 'cask "careerrat" do\nend\n' > "$fixture/repo/Casks/careerrat.rb"
printf 'cask "dilated" do\nend\n' > "$fixture/repo/Casks/dilated.rb"
printf 'preserve user trust\n' > "$fixture/user-config/homebrew/trust.json"
printf 'HOMEBREW_NO_ANALYTICS=1\n' > "$fixture/user-config/homebrew/brew.env"

cat > "$fixture/bin/brew" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  --repository)
    printf '%s\n' "$AUDIT_FIXTURE_ROOT/brew"
    ;;
  trust)
    [ "${2:-}" = --cask ]
    case "${3:-}" in
      codeswhat-ci/tap/*) [ -e "$AUDIT_FIXTURE_ROOT/repo/Casks/${3#codeswhat-ci/tap/}.rb" ] ;;
      *) exit 1 ;;
    esac
    [ "${XDG_CONFIG_HOME:-}" != "$AUDIT_FIXTURE_ROOT/user-config" ]
    [ -f "$XDG_CONFIG_HOME/homebrew/brew.env" ]
    mkdir -p "$XDG_CONFIG_HOME/homebrew"
    printf '%s\n' "$3" > "$XDG_CONFIG_HOME/homebrew/trust.json"
    printf '%s\n' "$XDG_CONFIG_HOME" > "$AUDIT_FIXTURE_ROOT/scoped-config"
    ;;
  audit)
    [ -f "${XDG_CONFIG_HOME:-}/homebrew/trust.json" ] || {
      echo 'Refusing to load cask from untrusted temporary tap' >&2
      exit 1
    }
    [ "$(cat "$XDG_CONFIG_HOME/homebrew/trust.json")" = "${!#}" ]
    case "${!#}" in codeswhat-ci/tap/*) ;; *) exit 1 ;; esac
    [ "$(readlink "$AUDIT_FIXTURE_ROOT/brew/Library/Taps/codeswhat-ci/homebrew-tap")" = "$AUDIT_FIXTURE_ROOT/repo" ]
    [ "${HOMEBREW_NO_ANALYTICS:-}" = 1 ] || grep -qx 'HOMEBREW_NO_ANALYTICS=1' "$XDG_CONFIG_HOME/homebrew/brew.env"
    printf '%s\n' "$*" > "$AUDIT_FIXTURE_ROOT/audit-args"
    printf '%s\n' "$*" >> "$AUDIT_FIXTURE_ROOT/audit-calls"
    if [ "${AUDIT_FIXTURE_FAIL_CASK:-}" = "${!#}" ]; then
      exit 1
    fi
    exit "${AUDIT_FIXTURE_EXIT:-0}"
    ;;
  *) exit 2 ;;
esac
SH
chmod +x "$fixture/bin/brew"
export PATH="$fixture/bin:$PATH"
export AUDIT_FIXTURE_ROOT="$fixture"
export XDG_CONFIG_HOME="$fixture/user-config"

bash "$fixture/repo/scripts/audit-casks.sh" careerrat
grep -qx 'audit --cask --os=macos --arch=all codeswhat-ci/tap/careerrat' "$fixture/audit-args"
[ "$(cat "$fixture/user-config/homebrew/trust.json")" = 'preserve user trust' ]
[ ! -e "$(cat "$fixture/scoped-config")" ]
[ ! -e "$fixture/brew/Library/Taps/codeswhat-ci/homebrew-tap" ]

unset XDG_CONFIG_HOME
export HOMEBREW_XDG_CONFIG_HOME="$fixture/user-config"
bash "$fixture/repo/scripts/audit-casks.sh" careerrat
[ "$(cat "$fixture/user-config/homebrew/trust.json")" = 'preserve user trust' ]
[ ! -e "$(cat "$fixture/scoped-config")" ]

bash "$fixture/repo/scripts/audit-casks.sh" --min-os careerrat
grep -qx 'audit --cask --os=macos --arch=all --online --only min_os codeswhat-ci/tap/careerrat' "$fixture/audit-args"
[ ! -e "$(cat "$fixture/scoped-config")" ]

export AUDIT_FIXTURE_EXIT=1
if bash "$fixture/repo/scripts/audit-casks.sh" --online careerrat; then
  echo 'Expected failed audit to propagate' >&2
  exit 1
fi
grep -qx 'audit --cask --os=macos --arch=all --online codeswhat-ci/tap/careerrat' "$fixture/audit-args"
[ "$(cat "$fixture/user-config/homebrew/trust.json")" = 'preserve user trust' ]
[ ! -e "$(cat "$fixture/scoped-config")" ]
[ ! -e "$fixture/brew/Library/Taps/codeswhat-ci/homebrew-tap" ]

# Unknown cask: usage error (2), exact message, and the tap is never linked.
unset AUDIT_FIXTURE_EXIT
rc=0
out="$(bash "$fixture/repo/scripts/audit-casks.sh" missing 2>&1)" || rc=$?
if [ "$rc" -ne 2 ]; then
  printf 'Expected unknown cask to exit 2, got %s\n%s\n' "$rc" "$out" >&2
  exit 1
fi
if [ "$out" != 'ERROR  no such cask: Casks/missing.rb' ]; then
  printf 'Unexpected unknown cask output: %s\n' "$out" >&2
  exit 1
fi
[ ! -e "$fixture/brew/Library/Taps/codeswhat-ci/homebrew-tap" ]

# No arguments: every cask under Casks/ is audited exactly once.
expect_calls() {
  local want="$1" got
  got="$(cat "$fixture/audit-calls" 2>/dev/null || true)"
  if [ "$got" != "$want" ]; then
    printf 'Unexpected audit calls.\nwanted:\n%s\ngot:\n%s\n' "$want" "$got" >&2
    exit 1
  fi
}

rm -f "$fixture/audit-calls"
bash "$fixture/repo/scripts/audit-casks.sh"
expect_calls 'audit --cask --os=macos --arch=all codeswhat-ci/tap/careerrat
audit --cask --os=macos --arch=all codeswhat-ci/tap/dilated'
[ ! -e "$fixture/brew/Library/Taps/codeswhat-ci/homebrew-tap" ]

rm -f "$fixture/audit-calls"
bash "$fixture/repo/scripts/audit-casks.sh" --online
expect_calls 'audit --cask --os=macos --arch=all --online codeswhat-ci/tap/careerrat
audit --cask --os=macos --arch=all --online codeswhat-ci/tap/dilated'

# No arguments with one failing cask: exit 1, and both casks were still audited.
rm -f "$fixture/audit-calls"
rc=0
AUDIT_FIXTURE_FAIL_CASK=codeswhat-ci/tap/careerrat bash "$fixture/repo/scripts/audit-casks.sh" >/dev/null || rc=$?
if [ "$rc" -ne 1 ]; then
  printf 'Expected one failing cask to exit 1, got %s\n' "$rc" >&2
  exit 1
fi
expect_calls 'audit --cask --os=macos --arch=all codeswhat-ci/tap/careerrat
audit --cask --os=macos --arch=all codeswhat-ci/tap/dilated'
[ ! -e "$fixture/brew/Library/Taps/codeswhat-ci/homebrew-tap" ]

# --skip-deprecated: a past-dated deprecated cask is skipped only with the flag,
# a future-dated one is still audited, in either flag order.
printf 'cask "oldie" do\n  deprecate! date: "2020-01-01", because: :unmaintained\nend\n' > "$fixture/repo/Casks/oldie.rb"
printf 'cask "future" do\n  deprecate! date: "2999-01-01", because: :unmaintained\nend\n' > "$fixture/repo/Casks/future.rb"

rm -f "$fixture/audit-calls"
out="$(bash "$fixture/repo/scripts/audit-casks.sh" --online --skip-deprecated)"
grep -qx 'skip   oldie (deprecated 2020-01-01)' <<<"$out"
expect_calls 'audit --cask --os=macos --arch=all --online codeswhat-ci/tap/careerrat
audit --cask --os=macos --arch=all --online codeswhat-ci/tap/dilated
audit --cask --os=macos --arch=all --online codeswhat-ci/tap/future'

rm -f "$fixture/audit-calls"
bash "$fixture/repo/scripts/audit-casks.sh" --skip-deprecated --online >/dev/null
expect_calls 'audit --cask --os=macos --arch=all --online codeswhat-ci/tap/careerrat
audit --cask --os=macos --arch=all --online codeswhat-ci/tap/dilated
audit --cask --os=macos --arch=all --online codeswhat-ci/tap/future'

rm -f "$fixture/audit-calls"
bash "$fixture/repo/scripts/audit-casks.sh" >/dev/null
grep -q 'codeswhat-ci/tap/oldie' "$fixture/audit-calls"

# Everything skipped: exit 0 before any brew call.
rm -f "$fixture/audit-calls"
cp "$fixture/bin/brew" "$fixture/brew.real"
printf '#!/usr/bin/env bash\necho "brew called: $*" >&2\nexit 99\n' > "$fixture/bin/brew"
out="$(bash "$fixture/repo/scripts/audit-casks.sh" --online --skip-deprecated oldie 2>&1)"
grep -qx 'skip   oldie (deprecated 2020-01-01)' <<<"$out"
if grep -q 'brew called' <<<"$out"; then
  echo 'Expected no brew call when every cask is skipped' >&2
  exit 1
fi
cp "$fixture/brew.real" "$fixture/bin/brew"
chmod +x "$fixture/bin/brew"
[ ! -e "$fixture/audit-calls" ]

# An audit failure still propagates alongside the flag.
rc=0
AUDIT_FIXTURE_FAIL_CASK=codeswhat-ci/tap/future bash "$fixture/repo/scripts/audit-casks.sh" --online --skip-deprecated >/dev/null || rc=$?
if [ "$rc" -ne 1 ]; then
  printf 'Expected failing cask with --skip-deprecated to exit 1, got %s\n' "$rc" >&2
  exit 1
fi

printf 'Isolated trust, audit failure and cleanup checks passed.\n'
