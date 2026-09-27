#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/tmp}/notchflow-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
exec "$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift" "${1:-build}" --disable-sandbox --scratch-path /tmp/notchflow-build
