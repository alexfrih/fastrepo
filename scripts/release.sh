#!/usr/bin/env bash
# Build, codesign (Developer ID), notarize, and staple FastRepo.app.
# One-time setup (keeps the app-specific password out of scripts/chat):
#   xcrun notarytool store-credentials fastrepo-notary \
#     --apple-id "<your apple id>" --team-id VP9U3RSL2K
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
mkdir -p "${BUNDLE}/Contents/MacOS" "${BUNDLE}/Contents/Resources" "${BUNDLE}/Contents/Frameworks"
cp ".build/release/${APP_NAME}" "${BUNDLE}/Contents/MacOS/${APP_NAME}"
cp scripts/Info.plist "${BUNDLE}/Contents/Info.plist"
cp Resources/AppIcon.icns "${BUNDLE}/Contents/Resources/AppIcon.icns"
cp Resources/MenuIcon.png "${BUNDLE}/Contents/Resources/MenuIcon.png"
cp -R ".build/release/Sparkle.framework" "${BUNDLE}/Contents/Frameworks/"
install_name_tool -add_rpath "@executable_path/../Frameworks" "${BUNDLE}/Contents/MacOS/${APP_NAME}" 2>/dev/null || true

echo "==> codesign (inside-out, hardened runtime)"
sign() { codesign --force --options runtime --timestamp --sign "${SIGN_ID}" "$@"; }
FW="${BUNDLE}/Contents/Frameworks/Sparkle.framework"
# Sparkle's nested helpers must be signed before the framework and the app.
while IFS= read -r -d '' x; do sign "$x"; done < <(find "${FW}" -name "*.xpc" -print0)
[ -e "${FW}/Versions/B/Updater.app" ] && sign "${FW}/Versions/B/Updater.app"
[ -e "${FW}/Versions/B/Autoupdate" ] && sign "${FW}/Versions/B/Autoupdate"
sign "${FW}"
sign "${BUNDLE}"
codesign --verify --strict --verbose=2 "${BUNDLE}"

echo "==> notarize"
ZIP="dist/${APP_NAME}.zip"
ditto -c -k --keepParent "${BUNDLE}" "${ZIP}"
xcrun notarytool submit "${ZIP}" --keychain-profile "${NOTARY_PROFILE}" --wait
xcrun stapler staple "${BUNDLE}"
xcrun stapler validate "${BUNDLE}"
rm -f "${ZIP}"; ditto -c -k --keepParent "${BUNDLE}" "${ZIP}"

echo "==> package dmg (website download; Sparkle keeps using the zip)"
DMG="dist/${APP_NAME}.dmg"
STAGE="$(mktemp -d)"
cp -R "${BUNDLE}" "${STAGE}/"
ln -s /Applications "${STAGE}/Applications"
hdiutil create -volname "${APP_NAME}" -srcfolder "${STAGE}" -ov -format UDZO "${DMG}"
rm -rf "${STAGE}"
codesign --force --timestamp --sign "${SIGN_ID}" "${DMG}"
xcrun notarytool submit "${DMG}" --keychain-profile "${NOTARY_PROFILE}" --wait
xcrun stapler staple "${DMG}"
xcrun stapler validate "${DMG}"

echo "==> done"
echo "Signed + notarized + stapled: ${BUNDLE}"
echo "Archive (feed to publish.sh): ${ZIP}"
echo "Disk image (website):         ${DMG}"
