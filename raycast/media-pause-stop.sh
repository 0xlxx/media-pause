#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Media Pause Stop
# @raycast.mode compact
# @raycast.icon icon.png
# @raycast.packageName Media Tools
# @raycast.description Stop the currently running media-pause timer

# Optional parameters:
# @raycast.author bjorn
# @raycast.keywords stop cancel abort kill timer

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/_media-pause-lib.sh"

PIDFILE="/tmp/media-pause.pid"
STATUSFILE="/tmp/media-pause.status"

if [ ! -f "$PIDFILE" ]; then
    echo "No timer is running."
    exit 0
fi

PID=$(cat "$PIDFILE" 2>/dev/null | awk '{print $1}')
if [ -z "$PID" ] || ! kill -0 "$PID" 2>/dev/null; then
    rm -f "$PIDFILE" "$STATUSFILE"
    echo "No timer is running."
    exit 0
fi

# Read what we're stopping
META=$(cat "$STATUSFILE" 2>/dev/null)
MODE=$(echo "$META" | awk '{print $3}')
LABEL=$(echo "$META" | awk '{for(i=4;i<=NF-1;i++) printf "%s%s", $i, (i<NF-1?" ":"")}')

# Kill the timer and all descendants (the watcher)
kill -TERM "$PID" 2>/dev/null
sleep 0.3
kill -KILL "$PID" 2>/dev/null
rm -f "$PIDFILE" "$STATUSFILE"

osascript -e "
    display notification \"Timer cancelled\"
    with title \"media-pause — Stopped\"
    subtitle \"$MODE · $LABEL\"
" 2>/dev/null

echo "Stopped: $MODE · $LABEL"
