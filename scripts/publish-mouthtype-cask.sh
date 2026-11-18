#!/usr/bin/env bash
# Validates the generated Mouthtype cask and commits it to main. Run from the
# repo root. Env: VERSION, GITHUB_TOKEN, and optionally CASK_ARTIFACT (default
# $RUNNER_TEMP/cask/mouthtype.rb).
#
# This never runs upstream code and never evaluates the cask. The generated
# file must equal the current Casks/mouthtype.rb except for the values on its
# one version line and one sha256 line, so any other change to the cask has to
# land through a reviewed PR. The push credential exists only for the push
# command and is never written to .git/config.
set -euo pipefail

src="${CASK_ARTIFACT:-${RUNNER_TEMP:-}/cask/mouthtype.rb}"
cask="Casks/mouthtype.rb"

if [ ! -f "$src" ]; then
  echo "::error::Generated cask artifact is missing"
  exit 1
fi
if ! [[ "${VERSION:-}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "::error::Release version '${VERSION:-}' is not X.Y.Z"
  exit 1
fi

version_re='^  version "[^"]*"$'
sha_re='^  sha256 "[^"]*"$'

count() { grep -Ec "$1" "$2" || true; }

for f in "$src" "$cask"; do
  if [ "$(count "$version_re" "$f")" != 1 ] || [ "$(count "$sha_re" "$f")" != 1 ]; then
    echo "::error::$f must have exactly one version line and one sha256 line"
    exit 1
  fi
done

generated="$(sed -n 's/^  version "\([^"]*\)"$/\1/p' "$src")"
sha="$(sed -n 's/^  sha256 "\([^"]*\)"$/\1/p' "$src")"
if [ "$generated" != "$VERSION" ]; then
  echo "::error::Generated cask version '$generated' does not match release '$VERSION'"
  exit 1
fi
if ! [[ "$sha" =~ ^[0-9a-f]{64}$ ]]; then
  echo "::error::Generated cask sha256 is not 64 lowercase hex characters"
  exit 1
fi

expected="$(mktemp)"
trap 'rm -f "$expected"' EXIT
sed -E -e "s/^(  version \")[^\"]*(\")\$/\\1${generated}\\2/" \
  -e "s/^(  sha256 \")[^\"]*(\")\$/\\1${sha}\\2/" "$cask" > "$expected"
if ! cmp -s "$expected" "$src"; then
  echo "::error::The generated cask changed more than version and sha256. Land the template change through a reviewed PR."
  diff -u "$expected" "$src" || true
  exit 1
fi

cp "$src" "$cask"
if git diff --quiet -- Casks/mouthtype.rb; then
  echo "Cask already matches; nothing to commit."
  exit 0
fi
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add Casks/mouthtype.rb
git commit -m "build(cask): update mouthtype to $VERSION"
auth="$(printf 'x-access-token:%s' "$GITHUB_TOKEN" | base64 | tr -d '\n')"
git -c "http.https://github.com/.extraheader=AUTHORIZATION: basic $auth" push origin HEAD:main
