#!/usr/bin/env bash
#
# release.sh — build a Release .app and package it into a distributable .dmg.
#
# Output:
#   dist/playback-popup.app   standalone, ad-hoc signed (double-click to launch)
#   dist/playback-popup.dmg   share this; open it and drag the app to Applications
#
# The .app is ad-hoc signed (no paid Apple Developer account), so on another Mac
# Gatekeeper blocks first launch — see the README's "Install & run (from the DMG)".
#
set -euo pipefail

PROJECT="playback-popup.xcodeproj"
SCHEME="playback-popup"
APP="playback-popup.app"
VOLNAME="playback-popup"

# Run from the repo root regardless of where the script is called from.
cd "$(dirname "$0")/.."

# xcodebuild needs full Xcode; if the command-line-tools instance is active,
# point DEVELOPER_DIR at Xcode.app (env override wins over `xcode-select`).
if ! xcodebuild -version >/dev/null 2>&1; then
    if [ -d /Applications/Xcode.app ]; then
        export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
    else
        echo "error: full Xcode is required (only Command Line Tools found)." >&2
        exit 1
    fi
fi

echo "==> Building Release app…"
rm -rf build dist
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -derivedDataPath build \
    -destination 'platform=macOS' \
    build | tail -1

BUILT="build/Build/Products/Release/$APP"
[ -d "$BUILT" ] || { echo "error: build did not produce $BUILT" >&2; exit 1; }

echo "==> Staging…"
mkdir -p dist/dmg-src
cp -R "$BUILT" "dist/dmg-src/$APP"
cp -R "$BUILT" "dist/$APP"

echo "==> Packaging DMG…"
if command -v create-dmg >/dev/null 2>&1; then
    # create-dmg adds its own drag-to-Applications link.
    create-dmg \
        --volname "$VOLNAME" \
        --window-size 560 360 \
        --icon "$APP" 150 185 \
        --app-drop-link 410 185 \
        --hide-extension "$APP" \
        --no-internet-enable \
        "dist/$VOLNAME.dmg" \
        "dist/dmg-src" >/dev/null
else
    # Fallback: plain read-only DMG with a hand-made Applications drop link.
    ln -sfn /Applications dist/dmg-src/Applications
    hdiutil create -volname "$VOLNAME" -srcfolder dist/dmg-src \
        -ov -format UDZO "dist/$VOLNAME.dmg" >/dev/null
fi

rm -rf dist/dmg-src
echo "==> Done:"
echo "    dist/$APP"
echo "    dist/$VOLNAME.dmg"
