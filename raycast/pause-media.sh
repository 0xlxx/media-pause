#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Pause Media
# @raycast.mode compact
# @raycast.icon icon-pause.png
# @raycast.packageName Media Timer
# @raycast.description Pause browser media immediately, or after an optional countdown

# Optional parameters:
# @raycast.author bjorn
# @raycast.keywords timer pause video audio youtube countdown

# Arguments:
# @raycast.argument1 { "type": "text", "placeholder": "Duration (optional): leave empty to pause now, or 30m | 1h for countdown", "optional": true }
# @raycast.argument2 { "type": "text", "placeholder": "Browser: chrome, brave, all (default: last used)", "optional": true }

export DURATION="${1}"
export USER_BROWSER="${2}"

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/_media-pause-lib.sh"

BROWSER="${USER_BROWSER:-$(recall_browser)}"
INSTALLED=$(detect_installed)
BROWSERS=$(resolve_browsers "$BROWSER" "$INSTALLED")

if [ -z "$BROWSERS" ]; then
    echo "No supported browser found. Installed: ${INSTALLED:-none}"
    exit 1
fi

BIN=$(find_bin)
if [ -z "$BIN" ]; then
    echo "media-pause not found. Install: brew install bjorn/homebrew-tap/media-pause"
    exit 1
fi

if [ -z "$DURATION" ]; then
    # Immediate pause, no timer
    LABEL=$(echo "$BROWSERS" | tr ',' ', ')
    "$BIN" -b "$BROWSERS" "1s" >/dev/null 2>&1 &
    echo "Paused $LABEL"
    [ -n "$USER_BROWSER" ] && remember_browser "$USER_BROWSER"
else
    # Countdown then pause
    [ -n "$USER_BROWSER" ] && remember_browser "$USER_BROWSER"
    launch_timer "pause" "$DURATION" "$BROWSER" "" "Pause"
fi
