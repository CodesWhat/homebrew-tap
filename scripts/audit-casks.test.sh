#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/repo/scripts" "$fixture/repo/Casks" "$fixture/user-config/homebrew"
cp "$script_dir/audit-casks.sh" "$fixture/repo/scripts/audit-casks.sh"
printf 'cask "careerrat" do\nend\n' > "$fixture/repo/Casks/careerrat.rb"
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
    [ "${3:-}" = codeswhat-ci/tap/careerrat ]
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
    [ "$(cat "$XDG_CONFIG_HOME/homebrew/trust.json")" = codeswhat-ci/tap/careerrat ]
    [ "$(readlink "$AUDIT_FIXTURE_ROOT/brew/Library/Taps/codeswhat-ci/homebrew-tap")" = "$AUDIT_FIXTURE_ROOT/repo" ]
    [ "${HOMEBREW_NO_ANALYTICS:-}" = 1 ] || grep -qx 'HOMEBREW_NO_ANALYTICS=1' "$XDG_CONFIG_HOME/homebrew/brew.env"
    printf '%s\n' "$*" > "$AUDIT_FIXTURE_ROOT/audit-args"
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

export AUDIT_FIXTURE_EXIT=1
if bash "$fixture/repo/scripts/audit-casks.sh" --online careerrat; then
  echo 'Expected failed audit to propagate' >&2
  exit 1
fi
grep -qx 'audit --cask --os=macos --arch=all --online codeswhat-ci/tap/careerrat' "$fixture/audit-args"
[ "$(cat "$fixture/user-config/homebrew/trust.json")" = 'preserve user trust' ]
[ ! -e "$(cat "$fixture/scoped-config")" ]
[ ! -e "$fixture/brew/Library/Taps/codeswhat-ci/homebrew-tap" ]

if bash "$fixture/repo/scripts/audit-casks.sh" missing; then
  echo 'Expected unknown cask to fail' >&2
  exit 1
fi
printf 'Isolated trust, audit failure and cleanup checks passed.\n'
