#!/usr/bin/env bash
#
# bootstrap.sh — install the optional prerequisite for polished DMGs.
#
# The release pipeline works without this (make-dmg.sh falls back to hdiutil),
# but `create-dmg` produces a nicer installer window with an Applications
# drop-target. Run this once.

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if command -v create-dmg >/dev/null 2>&1; then
  ok "create-dmg is already installed ($(command -v create-dmg))."
  exit 0
fi

command -v brew >/dev/null 2>&1 \
  || die "Homebrew not found. Install it from https://brew.sh, then re-run this script."

log "Installing create-dmg via Homebrew…"
brew install create-dmg
ok "create-dmg installed. You can now run ./scripts/release.sh"
