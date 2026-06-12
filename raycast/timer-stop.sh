#!/bin/bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Timer Stop
# @raycast.mode compact
# @raycast.icon icon-stop.png
# @raycast.packageName Media Timer
# @raycast.author 0xlxx
# @raycast.keywords timer stop kill cancel

pkill -f "^media-pause " || echo "No timer running"
