#!/bin/bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Timer Stop
# @raycast.mode compact
# @raycast.icon icon-stop.png
# @raycast.packageName Media Timer
# @raycast.author 0xlxx
# @raycast.keywords timer stop cancel

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_media-pause-lib.sh"
MP="$(mp_require)" || exit 1

exec "$MP" stop
