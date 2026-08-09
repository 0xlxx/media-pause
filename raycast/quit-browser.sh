#!/bin/bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Quit Browser
# @raycast.mode fullOutput
# @raycast.icon icon-quit.png
# @raycast.packageName Media Timer
# @raycast.author 0xlxx
# @raycast.keywords timer quit close browser

# Optional parameters:
# @raycast.argument1 { "type": "text", "placeholder": "Duration (default 1h)", "optional": true }
# @raycast.argument2 { "type": "dropdown", "placeholder": "Browser", "data": [{"title": "Chrome", "value": "chrome"}, {"title": "Brave", "value": "brave"}, {"title": "Edge", "value": "edge"}, {"title": "Arc", "value": "arc"}, {"title": "Chromium", "value": "chromium"}, {"title": "Opera", "value": "opera"}, {"title": "Vivaldi", "value": "vivaldi"}, {"title": "All", "value": "all"}] }

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_media-pause-lib.sh"
MP="$(mp_require)" || exit 1

BROWSER="${2:-chrome}"
exec "$MP" -q -b "$BROWSER" "${1:-1h}"
