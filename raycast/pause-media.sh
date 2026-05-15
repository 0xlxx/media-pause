#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Pause Media
# @raycast.mode compact
# @raycast.icon icon-pause.png
# @raycast.packageName Media Timer
# @raycast.description Pause browser media immediately, or after an optional countdown

# Optional parameters:
# @raycast.author 0xlxx
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

BIN=$(require_bin)

if [ -z "$DURATION" ]; then
    # Immediate pause — stop any running timer first
    CURRENT=$(read_current_timer)
    if [ -n "$CURRENT" ]; then
        STOP_PID=$(echo "$CURRENT" | awk '{print $1}')
        stop_timer "$STOP_PID"
    fi
    LABEL=$(echo "$BROWSERS" | tr ',' ', ')
    "$BIN" -b "$BROWSERS" "1s" >/dev/null 2>&1 &
    echo "Paused $LABEL"
    [ -n "$USER_BROWSER" ] && remember_browser "$USER_BROWSER"
    exit 0
else
    # Countdown then pause
    [ -n "$USER_BROWSER" ] && remember_browser "$USER_BROWSER"
    launch_timer "pause" "$DURATION" "$BROWSER" "" "Pause"
fi
