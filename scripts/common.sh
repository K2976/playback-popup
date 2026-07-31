#!/usr/bin/env bash
#
# common.sh — shared configuration and helpers for the release scripts.
# Sourced by build-app.sh, make-dmg.sh, release.sh and bootstrap.sh.
#
# Keeping all names/paths here means renaming the app or moving output
# directories is a single-file change.

set -euo pipefail

# --- Project coordinates -----------------------------------------------------

APP_NAME="playback-popup"
SCHEME="playback-popup"
PROJECT="playback-popup.xcodeproj"
CONFIG="Release"

# Repository root = parent of this scripts/ directory.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BUILD_DIR="$ROOT/build"          # xcodebuild derived data (git-ignored)
DIST_DIR="$ROOT/dist"            # release artifacts (git-ignored)
APP_PATH="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"

# --- Pretty logging ----------------------------------------------------------

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

# --- Toolchain ---------------------------------------------------------------

# Ensure `xcodebuild` is backed by a full Xcode (not just Command Line Tools).
# If the active developer dir isn't a real Xcode, fall back to the default
# /Applications/Xcode.app without needing `sudo xcode-select`.
ensure_xcode() {
  if ! /usr/bin/xcodebuild -version >/dev/null 2>&1; then
    local fallback="/Applications/Xcode.app/Contents/Developer"
    if [[ -d "$fallback" ]]; then
      export DEVELOPER_DIR="$fallback"
    fi
  fi
  /usr/bin/xcodebuild -version >/dev/null 2>&1 \
    || die "Xcode is required to build. Install Xcode from the App Store, then run: sudo xcode-select -s /Applications/Xcode.app"
}
