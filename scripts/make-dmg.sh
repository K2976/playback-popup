#!/usr/bin/env bash
#
# make-dmg.sh — package dist/<app>.app into a distributable dist/<app>.dmg.
#
# Uses `create-dmg` for a polished installer window (app icon + drag-to-
# Applications shortcut) when available, and falls back to plain `hdiutil` so
# the pipeline still produces a valid DMG without any extra tools installed.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

[[ -d "$APP_PATH" ]] || die "No app at $APP_PATH — run ./scripts/build-app.sh first."

rm -f "$DMG_PATH"

# Stage a clean folder containing only the app; the DMG is built from this.
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
cp -R "$APP_PATH" "$STAGE/"

make_with_hdiutil() {
  log "Building DMG with hdiutil (fallback)…"
  ln -s /Applications "$STAGE/Applications"   # drag-to-install shortcut
  hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGE" \
    -ov -format UDZO \
    "$DMG_PATH" >/dev/null
}

if command -v create-dmg >/dev/null 2>&1; then
  log "Building DMG with create-dmg…"
  # create-dmg may exit non-zero on cosmetic warnings, so judge success by
  # whether the DMG was actually written rather than by exit code.
  set +e
  create-dmg \
    --volname "$APP_NAME" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "$APP_NAME.app" 160 200 \
    --app-drop-link 440 200 \
    --no-internet-enable \
    "$DMG_PATH" \
    "$STAGE" >/dev/null 2>&1
  set -e
  [[ -f "$DMG_PATH" ]] || { warn "create-dmg did not produce a DMG; falling back."; make_with_hdiutil; }
else
  warn "create-dmg not installed (run ./scripts/bootstrap.sh for a nicer DMG)."
  make_with_hdiutil
fi

[[ -f "$DMG_PATH" ]] || die "Failed to create DMG."
ok "DMG created: $DMG_PATH"
