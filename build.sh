#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build/cache
export CLANG_MODULE_CACHE_PATH="$PWD/.build/cache"
export SWIFT_MODULECACHE_PATH="$PWD/.build/cache"
BUILD_ARGS=(--build-system native -c release --disable-sandbox --cache-path "$PWD/.build/cache")
APP="$PWD/dist/KnoTime.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
if [ "${KNOTIME_UNIVERSAL:-0}" = 1 ]; then
    swift build "${BUILD_ARGS[@]}" --arch arm64
    ARM_BIN=$(swift build "${BUILD_ARGS[@]}" --arch arm64 --show-bin-path)
    swift build "${BUILD_ARGS[@]}" --arch x86_64
    INTEL_BIN=$(swift build "${BUILD_ARGS[@]}" --arch x86_64 --show-bin-path)
    lipo -create "$ARM_BIN/KnoTime" "$INTEL_BIN/KnoTime" -output "$APP/Contents/MacOS/KnoTime"
else
    swift build "${BUILD_ARGS[@]}"
    BIN=$(swift build "${BUILD_ARGS[@]}" --show-bin-path)
    cp "$BIN/KnoTime" "$APP/Contents/MacOS/KnoTime"
fi
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
SPARKLE="$PWD/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
mkdir -p "$APP/Contents/Frameworks"
ditto "$SPARKLE" "$APP/Contents/Frameworks/Sparkle.framework"
cp .build/artifacts/sparkle/Sparkle/LICENSE "$APP/Contents/Resources/Sparkle-LICENSE.txt"
cp THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/"
# Local builds use ad-hoc signing. scripts/notarize.sh handles Developer ID releases.
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
if [ "${1:-}" = "--test" ]; then swift test --build-system native --disable-sandbox --cache-path "$PWD/.build/cache"; fi
printf '\nBuilt %s\n' "$APP"
