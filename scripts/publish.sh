#!/usr/bin/env bash
# Publish a release: upload the notarized zip to GitHub Releases, regenerate the
# EdDSA-signed Sparkle appcast, and push the Pages-hosted feed.
# Run AFTER scripts/release.sh.   Usage: scripts/publish.sh <version>   e.g. 0.1.0
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: publish.sh <version>  (e.g. 0.1.0)}"
APP_NAME="FastRepo"
ZIP="dist/${APP_NAME}.zip"
TAG="v${VERSION}"
REPO="alexfrih/fastrepo"
GEN="$(find .build -path '*/Sparkle/bin/generate_appcast' 2>/dev/null | head -1)"

[ -f "${ZIP}" ] || { echo "missing ${ZIP} — run scripts/release.sh first"; exit 1; }
[ -x "${GEN}" ] || { echo "generate_appcast not found — run a build first"; exit 1; }

echo "==> GitHub release ${TAG}"
gh release create "${TAG}" "${ZIP}" --repo "${REPO}" --title "${APP_NAME} ${VERSION}" --notes "FastRepo ${VERSION}" \
  || gh release upload "${TAG}" "${ZIP}" --repo "${REPO}" --clobber

echo "==> generate EdDSA-signed appcast"
mkdir -p docs
"${GEN}" --download-url-prefix "https://github.com/${REPO}/releases/download/${TAG}/" -o docs/appcast.xml dist

echo "==> publish feed (GitHub Pages)"
git add docs/appcast.xml
git commit -m "Publish appcast for ${TAG}" || true
git push origin main

echo "==> done — feed: https://alexfrih.github.io/fastrepo/appcast.xml"
