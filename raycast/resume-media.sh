#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Resume Media
# @raycast.mode compact
# @raycast.icon icon-resume.png
# @raycast.packageName Media Timer
# @raycast.description Resume previously-paused browser media, with optional countdown to re-pause

# Optional parameters:
# @raycast.author bjorn
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

BIN=$(find_bin)
if [ -z "$BIN" ]; then
    echo "media-pause not found. Install: brew install bjorn/homebrew-tap/media-pause"
    exit 1
fi

if [ -z "$DURATION" ]; then
    # Immediate resume, no timer
    LABEL=$(echo "$BROWSERS" | tr ',' ', ')
    "$BIN" -r -b "$BROWSERS" >/dev/null 2>&1 &
    echo "Resumed $LABEL"
    [ -n "$USER_BROWSER" ] && remember_browser "$USER_BROWSER"
else
    # Resume with countdown to re-pause
    [ -n "$USER_BROWSER" ] && remember_browser "$USER_BROWSER"
    launch_timer "resume" "$DURATION" "$BROWSER" "-r" "Resume"
fi
