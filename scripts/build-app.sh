#!/usr/bin/env bash
#
# build-app.sh — build a Release .app and export it to dist/.
#
# Produces a standalone, ad-hoc-signed app that launches from Finder without
# Xcode. No Apple Developer account is required.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

ensure_xcode

log "Building $APP_NAME ($CONFIG)…"
rm -rf "$APP_PATH"
mkdir -p "$DIST_DIR"

# Ad-hoc signing overrides: build locally without a Developer Team/profile.
# (The project's default signing style is Automatic, which would otherwise
# require an Apple Developer account.)
/usr/bin/xcodebuild \
  -project "$ROOT/$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -derivedDataPath "$BUILD_DIR" \
  -destination 'platform=macOS' \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES \
  DEVELOPMENT_TEAM="" \
  build

BUILT_APP="$BUILD_DIR/Build/Products/$CONFIG/$APP_NAME.app"
[[ -d "$BUILT_APP" ]] || die "Build succeeded but $BUILT_APP was not found."

cp -R "$BUILT_APP" "$DIST_DIR/"

# --- Extension point ---------------------------------------------------------
# To make the app portable to other Macs (Phase 2), this is where a future step
# would copy the mediaremote-adapter into "$APP_PATH/Contents/Resources" and then
# re-sign with:  codesign --force --deep --sign - "$APP_PATH"
# -----------------------------------------------------------------------------

ok "App exported: $APP_PATH"
