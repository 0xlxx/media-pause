#!/bin/bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Resume Media
# @raycast.mode compact
# @raycast.icon icon-resume.png
# @raycast.packageName Media Timer
# @raycast.author 0xlxx
# @raycast.keywords timer resume play video media

# Optional parameters:
# @raycast.argument1 { "type": "text", "placeholder": "Duration (optional): leave empty to resume now, or 30m to auto-pause after", "optional": true }
# @raycast.argument2 { "type": "text", "placeholder": "Browser: chrome, brave, all (default: chrome)", "optional": true }

BROWSER="${2:-chrome}"

media-pause -r --now -b "$BROWSER"

if [ -n "$1" ]; then
    exec media-pause -b "$BROWSER" "$1"
fi
