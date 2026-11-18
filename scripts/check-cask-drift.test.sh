#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/bin" "$fixture/repo/scripts" "$fixture/repo/audit_exceptions"
cp "$script_dir/check-cask-drift.sh" "$fixture/repo/scripts/check-cask-drift.sh"
cp "$script_dir/cask-version.sh" "$fixture/repo/scripts/cask-version.sh"

# Stub gh: `auth status` succeeds; `api --paginate <path> --jq <expr>` runs the
# real jq expression over each page file for the repo, one page per file.
# A FAIL file in the repo's page directory makes the call fail.
cat > "$fixture/bin/gh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  auth) exit "${GH_AUTH_EXIT:-0}" ;;
  api)
    [ "${2:-}" = --paginate ]
    [ "${4:-}" = --jq ]
    path="$3"
    case "$path" in
      repos/CodesWhat/*/releases\?per_page=100) ;;
      *) echo "unexpected api path: $path" >&2; exit 2 ;;
    esac
    name="${path#repos/CodesWhat/}"
    name="${name%%/*}"
    dir="$GH_FIXTURE_ROOT/pages/$name"
    if [ -e "$dir/FAIL" ]; then
      echo 'gh: HTTP 502 (stub)' >&2
      exit 1
    fi
    for page in "$dir"/page-*.json; do
      [ -e "$page" ] || continue
      jq -r "$5" "$page"
    done
    ;;
  *) echo "unexpected gh call: $*" >&2; exit 2 ;;
esac
SH
chmod +x "$fixture/bin/gh"

# Stub date: the deprecation check asks for today in UTC; pin it to a fixed day
# and pass every other invocation through to the real date.
cat > "$fixture/bin/date" <<'SH'
#!/usr/bin/env bash
if [ "$*" = '-u +%Y-%m-%d' ]; then
  printf '%s\n' "${DATE_FIXTURE_TODAY:-2026-06-15}"
else
  exec /bin/date "$@"
fi
SH
chmod +x "$fixture/bin/date"
export PATH="$fixture/bin:$PATH"
export GH_FIXTURE_ROOT="$fixture"

repo="$fixture/repo"
failures=0

# new_case <token> <pinned version> [allowlisted]
new_case() {
  rm -rf "$repo/Casks" "$fixture/pages"
  mkdir -p "$repo/Casks" "$fixture/pages/$1"
  printf 'cask "%s" do\n  version "%s"\nend\n' "$1" "$2" > "$repo/Casks/$1.rb"
  if [ "${3:-}" = allowlisted ]; then
    printf '{"%s": "all"}\n' "$1" > "$repo/audit_exceptions/github_prerelease_allowlist.json"
  else
    printf '{}\n' > "$repo/audit_exceptions/github_prerelease_allowlist.json"
  fi
}

# deprecate <token> <date>: add a deprecate! stanza to the cask.
deprecate() { printf '  deprecate! date: "%s", because: :unmaintained\n' "$2" >> "$repo/Casks/$1.rb"; }

# page <token> <n> <json array>
page() { printf '%s\n' "$3" > "$fixture/pages/$1/page-$2.json"; }

# run_case <name> <expected exit> <expected output substring>...
# A substring prefixed with ! must be absent from the output.
run_case() {
  local name="$1" want="$2" out rc=0
  shift 2
  out="$(bash "$repo/scripts/check-cask-drift.sh" 2>&1)" || rc=$?
  local ok=1
  [ "$rc" -eq "$want" ] || ok=0
  for needle in "$@"; do
    case "$needle" in
      '!'*) ! printf '%s\n' "$out" | grep -Fq -- "${needle#!}" || ok=0 ;;
      *) printf '%s\n' "$out" | grep -Fq -- "$needle" || ok=0 ;;
    esac
  done
  if [ "$ok" -eq 1 ]; then
    printf 'PASS  %s\n' "$name"
  else
    printf 'FAIL  %s (exit %s, wanted %s)\n%s\n' "$name" "$rc" "$want" "$out"
    failures=$((failures + 1))
  fi
}

# 1. Created later but published earlier loses to the later-published release.
new_case alpha 1.1.0
page alpha 1 '[
  {"tag_name":"v1.2.0","draft":false,"prerelease":false,"published_at":"2026-01-01T00:00:00Z"},
  {"tag_name":"v1.1.0","draft":false,"prerelease":false,"published_at":"2026-02-01T00:00:00Z"}
]'
run_case 'stable-only picks greatest published_at' 0 'ok     alpha        1.1.0'

# 2. Drafts and prereleases are ignored.
new_case alpha 1.0.0
page alpha 1 '[
  {"tag_name":"v9.0.0","draft":true,"prerelease":false,"published_at":null},
  {"tag_name":"v8.0.0","draft":true,"prerelease":false,"published_at":"2026-05-01T00:00:00Z"},
  {"tag_name":"v2.0.0-rc.1","draft":false,"prerelease":true,"published_at":"2026-04-01T00:00:00Z"},
  {"tag_name":"v1.0.0","draft":false,"prerelease":false,"published_at":"2026-01-01T00:00:00Z"}
]'
run_case 'stable-only ignores drafts and prereleases' 0 'ok     alpha        1.0.0'

# 3. The newest stable release lives on page 2.
new_case alpha 3.0.0
page alpha 1 '[{"tag_name":"v1.0.0","draft":false,"prerelease":false,"published_at":"2026-01-01T00:00:00Z"}]'
page alpha 2 '[{"tag_name":"v3.0.0","draft":false,"prerelease":false,"published_at":"2026-03-01T00:00:00Z"}]'
run_case 'stable release on page 2 is found' 0 'ok     alpha        3.0.0'

# 4. Allowlisted, latest published is a prerelease.
new_case alpha 2.0.0-rc.1 allowlisted
page alpha 1 '[
  {"tag_name":"v1.0.0","draft":false,"prerelease":false,"published_at":"2026-01-01T00:00:00Z"},
  {"tag_name":"v2.0.0-rc.1","draft":false,"prerelease":true,"published_at":"2026-02-01T00:00:00Z"}
]'
run_case 'allowlisted prerelease latest' 0 'ok     alpha        2.0.0-rc.1 (pre-release allowed)'

# 5. Allowlisted, a stable published after the prerelease but created earlier.
new_case alpha 2.0.0 allowlisted
page alpha 1 '[
  {"tag_name":"v2.0.0-rc.1","draft":false,"prerelease":true,"published_at":"2026-02-01T00:00:00Z"},
  {"tag_name":"v2.0.0","draft":false,"prerelease":false,"published_at":"2026-03-01T00:00:00Z"}
]'
run_case 'allowlisted stable published later says remove entry' 1 'remove the entry'

# 6. Pin mismatch.
new_case alpha 1.0.0
page alpha 1 '[{"tag_name":"v1.1.0","draft":false,"prerelease":false,"published_at":"2026-01-01T00:00:00Z"}]'
run_case 'pin mismatch reports drift' 1 'DRIFT  alpha        cask pins 1.0.0, CodesWhat/alpha latest is 1.1.0'

# 7. API failure is not reported as an empty release list.
new_case alpha 1.0.0
touch "$fixture/pages/alpha/FAIL"
run_case 'api failure reports could not list releases' 1 'could not list releases for CodesWhat/alpha' 'HTTP 502'

# 8. Successful but empty.
new_case alpha 1.0.0
page alpha 1 '[]'
run_case 'empty stable list' 1 'no published stable release found'
new_case alpha 1.0.0 allowlisted
page alpha 1 '[{"tag_name":"v1.0.0","draft":true,"prerelease":false,"published_at":null}]'
run_case 'empty allowlisted list' 1 'no published release found'

# 9. Deprecation skip: skipped from the deprecate! date onward, even when the
# release lookup would fail. A future date is still compared.
new_case alpha 1.0.0
deprecate alpha 2026-06-14
touch "$fixture/pages/alpha/FAIL"
run_case 'deprecated yesterday is skipped' 0 'skip   alpha'
new_case alpha 1.0.0
deprecate alpha 2026-06-15
touch "$fixture/pages/alpha/FAIL"
run_case 'deprecated today is skipped' 0 'skip   alpha'
new_case alpha 1.0.0
deprecate alpha 2026-06-16
page alpha 1 '[{"tag_name":"v1.1.0","draft":false,"prerelease":false,"published_at":"2026-01-01T00:00:00Z"}]'
run_case 'deprecated tomorrow is still compared' 1 'DRIFT  alpha        cask pins 1.0.0, CodesWhat/alpha latest is 1.1.0' '!skip'

# 10. A version.csv pin is compared by its version part only.
new_case alpha 0.3.0,66
page alpha 1 '[{"tag_name":"v0.3.0","draft":false,"prerelease":false,"published_at":"2026-01-01T00:00:00Z"}]'
run_case 'csv pin compares the version part' 0 'ok     alpha        0.3.0'

# 11. A tag that is not vX.Y.Z is named as a tagging change.
new_case alpha 1.2.3
page alpha 1 '[{"tag_name":"release-1.2.3","draft":false,"prerelease":false,"published_at":"2026-01-01T00:00:00Z"}]'
run_case 'non-semver latest tag is reported' 1 'latest tag release-1.2.3 is not vX.Y.Z'

# 12. A cask with no version stanza.
new_case alpha 1.0.0
printf 'cask "alpha" do\nend\n' > "$repo/Casks/alpha.rb"
page alpha 1 '[{"tag_name":"v1.0.0","draft":false,"prerelease":false,"published_at":"2026-01-01T00:00:00Z"}]'
run_case 'missing version stanza is reported' 1 'no version stanza found'

# 13. gh not authenticated.
new_case alpha 1.0.0
page alpha 1 '[{"tag_name":"v1.0.0","draft":false,"prerelease":false,"published_at":"2026-01-01T00:00:00Z"}]'
GH_AUTH_EXIT=1 run_case 'unauthenticated gh exits 2' 2 'gh is not authenticated'

# 14. Malformed allowlist JSON.
new_case alpha 1.0.0
page alpha 1 '[{"tag_name":"v1.0.0","draft":false,"prerelease":false,"published_at":"2026-01-01T00:00:00Z"}]'
printf 'not json\n' > "$repo/audit_exceptions/github_prerelease_allowlist.json"
run_case 'malformed allowlist exits 2' 2 'could not parse'

# 15. Allowlist matching is exact: alpha-cli being listed must not allow alpha.
new_case alpha 1.0.0
printf '{"alpha-cli": "all"}\n' > "$repo/audit_exceptions/github_prerelease_allowlist.json"
page alpha 1 '[
  {"tag_name":"v1.0.0","draft":false,"prerelease":false,"published_at":"2026-01-01T00:00:00Z"},
  {"tag_name":"v2.0.0-rc.1","draft":false,"prerelease":true,"published_at":"2026-02-01T00:00:00Z"}
]'
run_case 'allowlist entry is not a substring match' 0 'ok     alpha        1.0.0' '!pre-release allowed'

if [ "$failures" -ne 0 ]; then
  printf '%s case(s) failed.\n' "$failures" >&2
  exit 1
fi
printf 'Cask drift release selection checks passed.\n'
