#!/bin/bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Timer Status
# @raycast.mode fullOutput
# @raycast.icon icon-status.png
# @raycast.packageName Media Timer
# @raycast.author 0xlxx
# @raycast.keywords timer status progress

# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_media-pause-lib.sh"
MP="$(mp_require)" || exit 1

exec "$MP" status
