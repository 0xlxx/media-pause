#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Timer Stop
# @raycast.mode compact
# @raycast.icon icon-stop.png
# @raycast.packageName Media Timer
# @raycast.description Stop the currently running timer

# Optional parameters:
# @raycast.author 0xlxx
# @raycast.keywords timer stop cancel abort kill

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/_media-pause-lib.sh"

CURRENT=$(read_current_timer)
if [ -z "$CURRENT" ]; then
    echo "No timer is running."
    exit 0
fi

PID=$(echo "$CURRENT" | awk '{print $1}')
META=$(cat "$STATUSFILE" 2>/dev/null)
MODE=$(echo "$META" | awk '{print $3}')
LABEL=$(echo "$META" | awk '{for(i=4;i<=NF-1;i++) printf "%s%s", $i, (i<NF-1?" ":"")}')

stop_timer "$PID"

osascript -e "
    display notification \"Timer cancelled\"
    with title \"Timer Stopped\"
    subtitle \"$MODE · $LABEL\"
" 2>/dev/null

echo "Stopped ($MODE · $LABEL)"
