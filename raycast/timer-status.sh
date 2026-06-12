#!/bin/bash
# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Timer Status
# @raycast.mode compact
# @raycast.icon icon-status.png
# @raycast.packageName Media Timer
# @raycast.author 0xlxx
# @raycast.keywords timer status pipe

PID=$(pgrep -f "^media-pause " | head -1)
if [ -z "$PID" ]; then
    echo "No timer running"
else
    echo "Timer running (PID $PID)"
fi
