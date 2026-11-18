#!/usr/bin/env bash
# Validates the generated Mouthtype cask and opens a pull request for it. Run
# from the repo root. Env: VERSION, GITHUB_TOKEN, GH_TOKEN (for gh), and
# optionally CASK_ARTIFACT (default $RUNNER_TEMP/cask/mouthtype.rb).
#
# This never runs upstream code and never evaluates the cask. The generated
# file must equal the current Casks/mouthtype.rb except for the values on its
# one version line and one sha256 line, so any other change to the cask has to
# land through a reviewed PR. The push credential exists only for the push
# command and is never written to .git/config. Nothing here pushes to main: the
# cask goes onto mouthtype/vX.Y.Z, a PR is opened (or reused), cask-ci is
# dispatched on the branch, and cask-pr-merge.yml merges it once that passes.
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
branch="mouthtype/v$VERSION"
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git checkout -q -B "$branch"
git add Casks/mouthtype.rb
git commit -m "build(cask): update mouthtype to $VERSION"

auth="$(printf 'x-access-token:%s' "$GITHUB_TOKEN" | base64 | tr -d '\n')"
push() {
  git -c "http.https://github.com/.extraheader=AUTHORIZATION: basic $auth" \
    push "$@" origin "refs/heads/$branch:refs/heads/$branch"
}
# Only this mouthtype/ branch is ever force-pushed, and only if the remote
# copy is what we last saw, to replace a stale branch from an earlier run.
if ! push 2>/dev/null; then
  git -c "http.https://github.com/.extraheader=AUTHORIZATION: basic $auth" \
    fetch -q origin "refs/heads/$branch:refs/remotes/origin/$branch"
  push --force-with-lease="refs/heads/$branch:refs/remotes/origin/$branch"
fi

bash "$(dirname "$0")/open-cask-pr.sh" "$branch" \
  "build(cask): update mouthtype to $VERSION" \
  "Updates the mouthtype cask to release $VERSION. Generated and validated by update-mouthtype-cask.yml."
