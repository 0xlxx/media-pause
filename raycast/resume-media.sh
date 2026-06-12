#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Resume Media
# @raycast.mode compact
# @raycast.icon icon-resume.png
# @raycast.packageName Media Timer
# @raycast.description Resume previously-paused browser media, with optional countdown to re-pause

# Optional parameters:
# @raycast.author 0xlxx
# @raycast.keywords timer resume play video media unpause

# Arguments:
# @raycast.argument1 { "type": "text", "placeholder": "Duration (optional): leave empty to resume now, or set to auto-pause after", "optional": true }
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
    # Immediate resume — stop any running timer first
    CURRENT=$(read_current_timer)
    if [ -n "$CURRENT" ]; then
        STOP_PID=$(echo "$CURRENT" | awk '{print $1}')
        stop_timer "$STOP_PID"
    fi
    LABEL=$(echo "$BROWSERS" | tr ',' ', ')
    if "$BIN" -r --now -b "$BROWSERS" >/dev/null 2>&1; then
        echo "Resumed $LABEL"
    else
        echo "Failed to resume $LABEL"
    fi
    [ -n "$USER_BROWSER" ] && remember_browser "$USER_BROWSER"
    exit 0
else
    # Resume with countdown to re-pause
    [ -n "$USER_BROWSER" ] && remember_browser "$USER_BROWSER"
    launch_timer "resume" "$DURATION" "$BROWSER" "-r" "Resume"
fi
