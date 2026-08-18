#!/usr/bin/env bash
# Build a fresh T3 Code desktop artifact from an upstream branch, publish it,
# and point sources.json at it.
#
#   ./update.sh                              # rebuild the branch in sources.json
#   ./update.sh t3code/some-other-branch      # switch branches
#
# There is no upstream release to track. T3 Code publishes the CLI to npm, but
# the desktop app for a branch exists only if someone builds it, which is what
# this does -- on the remote builder, because the build wants Node 24, pnpm,
# vite-plus and a Rust toolchain.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

BUILDER="${T3CODE_BUILDER:-stuff}"          # ssh host with t3-remote checked out
REMOTE_DIR="${T3CODE_REMOTE_DIR:-/root/t3-remote}"
OUT_DIR="${T3CODE_OUT_DIR:-/root/stuff/devkit/dist}"
BRANCH="${1:-$(jq -r .branch sources.json)}"
REPO="${T3CODE_RELEASE_REPO:-cjavad/nixpille-t3code}"

log() { printf '\033[1;36m>\033[0m %s\n' "$*"; }

log "building $BRANCH on $BUILDER"
ssh "$BUILDER" "set -e
  cd $REMOTE_DIR
  docker build --target builder -t t3code-builder:latest \
    --build-arg T3_REF='$BRANCH' --build-arg T3_CACHE_BUST=\$(git ls-remote https://github.com/pingdotgg/t3code.git 'refs/heads/$BRANCH' | cut -f1) .
  docker build -f Dockerfile.desktop -t t3code-desktop-builder:latest .
  rm -f $OUT_DIR/*.AppImage
  docker run --rm -v $OUT_DIR:/out -w /src t3code-desktop-builder:latest \
    sh -c 'vp run dist:desktop:linux && cp release/*.AppImage /out/'"

commit="$(ssh "$BUILDER" "docker run --rm --entrypoint cat t3code-builder:latest /opt/t3code/.t3-build-sha")"
remote_file="$(ssh "$BUILDER" "ls $OUT_DIR/*.AppImage | head -1")"
asset="$(basename "$remote_file")"
version="$(printf '%s' "$asset" | sed -E 's/^T3-Code-(.+)-x86_64\.AppImage$/\1/')"

log "built $version @ ${commit:0:12}"
scp "$BUILDER:$remote_file" "./$asset"

hash="$(nix hash file --type sha256 --sri "./$asset")"
tag="v${version}-$(printf '%s' "$BRANCH" | sed 's|.*/||')"
url="https://github.com/$REPO/releases/download/$tag/$asset"

log "publishing $tag"
gh release view "$tag" --repo "$REPO" >/dev/null 2>&1 \
  && gh release upload "$tag" "./$asset" --repo "$REPO" --clobber \
  || gh release create "$tag" "./$asset" --repo "$REPO" \
       --title "T3 Code $version ($BRANCH)" \
       --notes "Desktop AppImage built from \`$BRANCH\` at \`$commit\`.

Wire-compatible only with a server built from the same branch."

jq --arg b "$BRANCH" --arg c "$commit" --arg v "$version" --arg u "$url" --arg h "$hash" \
   '.branch=$b | .commit=$c | .version=$v | .url=$u | .hashes["x86_64-linux"]=$h' \
   sources.json > sources.json.tmp && mv sources.json.tmp sources.json

rm -f "./$asset"
log "sources.json updated -- commit it"
git --no-pager diff -- sources.json
