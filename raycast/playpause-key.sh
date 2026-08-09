#!/bin/bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Play/Pause Key
# @raycast.mode compact
# @raycast.icon icon-key.png
# @raycast.packageName Media Timer
# @raycast.author 0xlxx
# @raycast.keywords timer playpause media key

# Optional parameters:
# @raycast.argument1 { "type": "text", "placeholder": "Duration (default 1h)", "optional": true }

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_media-pause-lib.sh"
MP="$(mp_require)" || exit 1

exec "$MP" -p "${1:-1h}"
