#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Media Resume
# @raycast.mode compact
# @raycast.icon icon-resume.png
# @raycast.packageName Media Tools
# @raycast.description Resume previously-paused browser media, with optional countdown

# Optional parameters:
# @raycast.author bjorn
# @raycast.keywords timer resume play video media

# Arguments:
# @raycast.argument1 { "type": "text", "placeholder": "Duration (optional): resume then pause after this time", "optional": true }
# @raycast.argument2 { "type": "text", "placeholder": "Browser: chrome, brave, all (default: last used)", "optional": true }

DURATION="${1}"
BROWSER="${2}"

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/_media-pause-lib.sh"

# Resume without duration = immediate resume, no timer
if [ -z "$DURATION" ]; then
    # Immediate resume mode — run directly
    BROWSER="${BROWSER:-$(recall_browser)}"
    INSTALLED=$(detect_installed)
    BROWSERS=$(resolve_browsers "$BROWSER" "$INSTALLED")
    BIN=$(find_bin)
    if [ -z "$BIN" ]; then
        echo "media-pause not found. Install: brew install bjorn/homebrew-tap/media-pause"
        exit 1
    fi
    if [ -z "$BROWSERS" ]; then
        echo "No supported browser found. Installed: ${INSTALLED:-none}"
        exit 1
    fi
    LABEL=$(echo "$BROWSERS" | tr ',' ', ')
    "$BIN" -r -b "$BROWSERS" >/dev/null 2>&1 &
    echo "Resume: immediate → $(echo "$BROWSERS" | tr ',' '\n' | wc -l | tr -d ' ') browser(s) ($LABEL)"
    [ -n "$2" ] && remember_browser "$2"
else
    launch_timer "resume" "$DURATION" "$BROWSER" "-r" "Resume"
fi
