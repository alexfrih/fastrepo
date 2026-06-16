#!/usr/bin/env bash
# Build, codesign (Developer ID), and notarize FastRepo.
# One-time setup (keeps the app-specific password out of scripts/chat):
#   xcrun notarytool store-credentials fastrepo-notary \
#     --apple-id "<your apple id>" --team-id VP9U3RSL2K --password "<app-specific password>"
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="FastRepo"
BUNDLE="dist/${APP_NAME}.app"
SIGN_ID="${SIGN_ID:-Developer ID Application: Solar Beam (VP9U3RSL2K)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-fastrepo-notary}"

echo "==> build"
swift build -c release

echo "==> assemble ${BUNDLE}"
rm -rf dist
mkdir -p "${BUNDLE}/Contents/MacOS" "${BUNDLE}/Contents/Resources"
cp ".build/release/${APP_NAME}" "${BUNDLE}/Contents/MacOS/${APP_NAME}"
cp scripts/Info.plist "${BUNDLE}/Contents/Info.plist"
cp Resources/AppIcon.icns "${BUNDLE}/Contents/Resources/AppIcon.icns"
cp Resources/MenuIcon.png "${BUNDLE}/Contents/Resources/MenuIcon.png"

echo "==> codesign (hardened runtime + timestamp)"
codesign --force --options runtime --timestamp --sign "${SIGN_ID}" "${BUNDLE}"
codesign --verify --strict --verbose=2 "${BUNDLE}"

echo "==> notarize"
ZIP="dist/${APP_NAME}.zip"
ditto -c -k --keepParent "${BUNDLE}" "${ZIP}"
xcrun notarytool submit "${ZIP}" --keychain-profile "${NOTARY_PROFILE}" --wait
xcrun stapler staple "${BUNDLE}"
xcrun stapler validate "${BUNDLE}"

# Re-zip the stapled app for distribution / Sparkle.
rm -f "${ZIP}"
ditto -c -k --keepParent "${BUNDLE}" "${ZIP}"

echo "==> done"
echo "Signed + notarized + stapled: ${BUNDLE}"
echo "Distributable archive:        ${ZIP}"
# TODO (auto-update): sign ${ZIP} with Sparkle's EdDSA key, append to appcast.xml, publish feed.
