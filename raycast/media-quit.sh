#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Media Quit
# @raycast.mode compact
# @raycast.icon icon.png
# @raycast.packageName Media Tools
# @raycast.description Countdown then quit the browser entirely

# Optional parameters:
# @raycast.author bjorn
# @raycast.keywords timer quit close browser shutdown

# Arguments:
# @raycast.argument1 { "type": "text", "placeholder": "Duration: 15m | 30m | 1h | 2h (default 1h)", "optional": true }
# @raycast.argument2 { "type": "text", "placeholder": "Browser: chrome, brave, all (default: last used)", "optional": true }

DURATION="${1:-1h}"
BROWSER="${2}"

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/_media-pause-lib.sh"

launch_timer "quit" "$DURATION" "$BROWSER" "-q" "Quit"
