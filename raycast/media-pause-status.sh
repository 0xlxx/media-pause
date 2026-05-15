#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Media Pause Status
# @raycast.mode compact
# @raycast.icon ⏱
# @raycast.packageName Media Tools
# @raycast.description Check status of running media-pause timer

# Optional parameters:
# @raycast.author bjorn
# @raycast.keywords status timer progress check

PIDFILE="/tmp/media-pause.pid"

if [ ! -f "$PIDFILE" ]; then
    echo "No media-pause timer is running."
    exit 0
fi

PID=$(cat "$PIDFILE" 2>/dev/null)
if [ -z "$PID" ] || ! ps -p "$PID" >/dev/null 2>&1; then
    rm -f "$PIDFILE"
    echo "No media-pause timer is running."
    exit 0
fi

# Extract command line to show what it's doing
CMD=$(ps -p "$PID" -o command= 2>/dev/null | sed 's/.*media-pause/media-pause/')
if [ -z "$CMD" ]; then
    echo "Media-pause timer is running (PID $PID)."
else
    echo "Running: $CMD"
fi
