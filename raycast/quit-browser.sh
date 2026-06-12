#!/bin/bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Quit Browser
# @raycast.mode compact
# @raycast.icon icon-quit.png
# @raycast.packageName Media Timer
# @raycast.author 0xlxx
# @raycast.keywords timer quit close browser

# Optional parameters:
# @raycast.argument1 { "type": "text", "placeholder": "Duration (optional): 30m | 1h", "optional": true }
# @raycast.argument2 { "type": "text", "placeholder": "Browser: chrome, brave, all (default: chrome)", "optional": true }

BROWSER="${2:-chrome}"
exec media-pause -q -b "$BROWSER" "$1"
