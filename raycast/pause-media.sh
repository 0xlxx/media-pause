#!/bin/bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Pause Media
# @raycast.mode fullOutput
# @raycast.icon icon-pause.png
# @raycast.packageName Media Timer
# @raycast.author 0xlxx
# @raycast.keywords timer pause video media countdown

# Optional parameters:
# @raycast.argument1 { "type": "text", "placeholder": "Duration (optional): 30m | 1h | 3600", "optional": true }
# @raycast.argument2 { "type": "dropdown", "placeholder": "Browser", "data": [{"title": "Chrome", "value": "chrome"}, {"title": "Brave", "value": "brave"}, {"title": "Edge", "value": "edge"}, {"title": "Arc", "value": "arc"}, {"title": "Chromium", "value": "chromium"}, {"title": "Opera", "value": "opera"}, {"title": "Vivaldi", "value": "vivaldi"}, {"title": "All", "value": "all"}] }

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_media-pause-lib.sh"
MP="$(mp_require)" || exit 1

BROWSER="${2:-chrome}"
if [ -z "$1" ]; then
    exec "$MP" --now -b "$BROWSER"
else
    exec "$MP" -b "$BROWSER" "$1"
fi
