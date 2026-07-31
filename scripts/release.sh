#!/usr/bin/env bash
#
# release.sh — the one command.
#
# Builds a Release .app and packages it into a DMG, both in dist/.
#
#   ./scripts/release.sh
#
# Output:
#   dist/playback-popup.app
#   dist/playback-popup.dmg

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/common.sh"

"$HERE/build-app.sh"
"$HERE/make-dmg.sh"

log "Done. Artifacts in dist/:"
ls -lh "$DIST_DIR" | sed '1d'
ok "Share $DMG_PATH — open it, then drag $APP_NAME to Applications."
