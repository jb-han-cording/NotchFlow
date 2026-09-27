#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."

echo "==> Building Release Universal Binary..."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
"$DEVELOPER_DIR/usr/bin/xcodebuild" -project NotchFlow.xcodeproj -scheme NotchFlow -configuration Release -derivedDataPath build CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO OTHER_SWIFT_FLAGS=-disable-sandbox build

APP_PATH="build/Build/Products/Release/NotchFlow.app"
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

echo "==> Successfully created $DMG_OUTPUT!"
ls -lh "$DMG_OUTPUT"
