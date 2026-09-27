#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
icon_stage=$(mktemp -d /tmp/notchflow-icon.XXXXXX)
icon_set="$icon_stage/AppIcon.iconset"
mkdir -p "$icon_set"
for points in 16 32 128 256 512; do
    sips -z "$points" "$points" Resources/Branding/AppIcon.png --out "$icon_set/icon_${points}x${points}.png" >/dev/null
    pixels=$((points * 2))
    sips -z "$pixels" "$pixels" Resources/Branding/AppIcon.png --out "$icon_set/icon_${points}x${points}@2x.png" >/dev/null
done
iconutil -c icns "$icon_set" -o Resources/AppIcon.icns
