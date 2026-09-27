#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
args=()
configuration="${CONFIGURATION:-Debug}"
# Only for build environments that prohibit the compiler's nested sandbox.
if [[ "${NOTCHFLOW_DISABLE_MACRO_SANDBOX:-0}" == "1" ]]; then
    args+=(OTHER_SWIFT_FLAGS=-disable-sandbox)
fi
if [[ "$configuration" == "Release" ]]; then
    args+=(CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO)
fi
exec "$DEVELOPER_DIR/usr/bin/xcodebuild" -project NotchFlow.xcodeproj -scheme NotchFlow -destination 'platform=macOS,arch=arm64' -configuration "$configuration" -derivedDataPath build CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES "${args[@]}" build
