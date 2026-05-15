#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Media PlayPause
# @raycast.mode compact
# @raycast.icon icon.png
# @raycast.packageName Media Tools
# @raycast.description Countdown then send system play/pause key (works with any app)

# Optional parameters:
# @raycast.author bjorn
# @raycast.keywords timer playpause media key spotify music

# Arguments:
# @raycast.argument1 { "type": "text", "placeholder": "Duration: 30m | 1h | 2h (default 1h)", "optional": true }

DURATION="${1:-1h}"

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/_media-pause-lib.sh"

# PlayPause doesn't need a browser (system media key)
BIN=$(find_bin)
if [ -z "$BIN" ]; then
    echo "media-pause not found. Install: brew install bjorn/homebrew-tap/media-pause"
    exit 1
fi
DUR_SEC=$(parse_duration_seconds "$DURATION")

"$BIN" -p "$DURATION" >/dev/null 2>&1 &
PID=$!
echo "$PID" > "$PIDFILE"
echo "$(date +%s) $DUR_SEC PlayPause system" > "$STATUSFILE"

osascript -e "
    display notification \"$DURATION countdown started\"
    with title \"media-pause — PlayPause\"
    subtitle \"Timer running\"
" 2>/dev/null

(
    while kill -0 "$PID" 2>/dev/null; do sleep 1; done
    rm -f "$PIDFILE" "$STATUSFILE"
    osascript -e "
        display notification \"Done — media key sent\"
        with title \"media-pause — PlayPause\"
        subtitle \"Countdown finished\"
    " 2>/dev/null
) &
disown

echo "PlayPause: $DURATION → system media key  |  Status: run 'Media Pause Status'"
