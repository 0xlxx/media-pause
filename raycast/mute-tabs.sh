#!/bin/bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Mute Tabs
# @raycast.mode compact
# @raycast.icon icon-mute.png
# @raycast.packageName Media Timer
# @raycast.author 0xlxx
# @raycast.keywords timer mute silent audio

# Optional parameters:
# @raycast.argument1 { "type": "text", "placeholder": "Duration (optional): 30m | 1h", "optional": true }
# @raycast.argument2 { "type": "text", "placeholder": "Browser: chrome, brave, all (default: chrome)", "optional": true }

BROWSER="${2:-chrome}"
exec media-pause -m -b "$BROWSER" "$1"
