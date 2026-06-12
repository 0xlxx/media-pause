#!/bin/bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Pause Media
# @raycast.mode compact
# @raycast.icon icon-pause.png
# @raycast.packageName Media Timer
# @raycast.author 0xlxx
# @raycast.keywords timer pause video media countdown

# Optional parameters:
# @raycast.argument1 { "type": "text", "placeholder": "Duration (optional): 30m | 1h | 3600", "optional": true }
# @raycast.argument2 { "type": "text", "placeholder": "Browser: chrome, brave, all (default: chrome)", "optional": true }

BROWSER="${2:-chrome}"

if [ -z "$1" ]; then
    exec media-pause --now -b "$BROWSER"
else
    exec media-pause -b "$BROWSER" "$1"
fi
