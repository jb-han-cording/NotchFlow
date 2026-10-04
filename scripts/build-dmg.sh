#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."

echo "==> Building Release Universal Binary..."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
"$DEVELOPER_DIR/usr/bin/xcodebuild" -project NotchFlow.xcodeproj -scheme NotchFlow -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO OTHER_SWIFT_FLAGS=-disable-sandbox build

APP_PATH="build/Build/Products/Release/NotchFlow.app"

# Sparkle ships pre-signed nested helpers. When this local build uses the
# ad-hoc identity above, re-sign the complete bundle so macOS does not reject
# the framework because its Team ID differs from the main executable.
codesign --force --deep --sign - "$APP_PATH"

DMG_STAGING="build/dmg_staging"
DMG_OUTPUT="NotchFlow.dmg"

echo "==> Preparing DMG Staging Directory..."
rm -rf "$DMG_STAGING" "$DMG_OUTPUT"
mkdir -p "$DMG_STAGING"

cp -R "$APP_PATH" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

echo "==> Creating DMG Disk Image..."
hdiutil create -volname "NotchFlow" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_OUTPUT"

rm -rf "$DMG_STAGING"

SPARKLE_BIN="build/SourcePackages/artifacts/sparkle/Sparkle/bin"
SPARKLE_ACCOUNT="notchflow"
if [[ ! -x "$SPARKLE_BIN/generate_keys" || ! -x "$SPARKLE_BIN/sign_update" ]]; then
    echo "Sparkle signing tools are missing; refusing to publish an unsigned update." >&2
    exit 1
fi
PUBLIC_KEY="$("$SPARKLE_BIN/generate_keys" --account "$SPARKLE_ACCOUNT" -p)"
BUNDLE_KEY="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$APP_PATH/Contents/Info.plist")"
if [[ "$PUBLIC_KEY" != "$BUNDLE_KEY" ]]; then
    echo "Sparkle signing key does not match the app's SUPublicEDKey." >&2
    exit 1
fi
echo "==> Sparkle signature and enclosure length:"
"$SPARKLE_BIN/sign_update" --account "$SPARKLE_ACCOUNT" "$DMG_OUTPUT"

echo "==> Successfully created $DMG_OUTPUT!"
ls -lh "$DMG_OUTPUT"
