#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Play/Pause Key
# @raycast.mode compact
# @raycast.icon icon-key.png
# @raycast.packageName Media Timer
# @raycast.description Countdown then send system play/pause key (works with any app: Spotify, Music, VLC...)

# Optional parameters:
# @raycast.author bjorn
# @raycast.keywords timer playpause media key spotify music countdown

# Arguments:
# @raycast.argument1 { "type": "text", "placeholder": "Duration: 30m | 1h | 2h (default 1h)", "optional": true }

DURATION="${1:-1h}"

DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/_media-pause-lib.sh"

PIDFILE="/tmp/media-pause.pid"
STATUSFILE="/tmp/media-pause.status"

CURRENT=$(read_current_timer)
if [ -n "$CURRENT" ]; then
    OLD_META=$(cat "$STATUSFILE" 2>/dev/null)
    OLD_MODE=$(echo "$OLD_META" | awk '{print $3}')
    OLD_LABEL=$(echo "$OLD_META" | awk '{for(i=4;i<=NF-1;i++) printf "%s%s", $i, (i<NF-1?" ":"")}')
    OLD_START=$(echo "$OLD_META" | awk '{print $1}')
    OLD_TOTAL=$(echo "$OLD_META" | awk '{print $2}')
    OLD_ELAPSED=$(($(date +%s) - OLD_START))
    OLD_REMAIN=$((OLD_TOTAL - OLD_ELAPSED))
    [ $OLD_REMAIN -lt 0 ] && OLD_REMAIN=0
    OLD_FMT=$(printf "%02d:%02d" $((OLD_REMAIN/60)) $((OLD_REMAIN%60)))
    echo "Timer already running: $OLD_MODE · $OLD_LABEL · ${OLD_FMT}m remaining"
    echo "Stop it first: run 'Timer Stop'"
    exit 1
fi

BIN=$(find_bin)
if [ -z "$BIN" ]; then
    echo "media-pause not found. Install: brew install bjorn/homebrew-tap/media-pause"
    exit 1
fi
DUR_SEC=$(parse_duration_seconds "$DURATION")
INSTANCE_ID="$(date +%s).$$"

"$BIN" -p "$DURATION" >/dev/null 2>&1 &
PID=$!
echo "$PID $INSTANCE_ID" > "$PIDFILE"
echo "$(date +%s) $DUR_SEC Key system $INSTANCE_ID" > "$STATUSFILE"

osascript -e "
    display notification \"$DURATION countdown started\"
    with title \"Play/Pause Key\"
    subtitle \"Timer running\"
" 2>/dev/null

(
    while kill -0 "$PID" 2>/dev/null; do sleep 1; done
    CUR_IID=""
    [ -f "$PIDFILE" ] && CUR_IID=$(cat "$PIDFILE" 2>/dev/null | awk '{print $2}')
    if [ "$CUR_IID" = "$INSTANCE_ID" ]; then
        rm -f "$PIDFILE" "$STATUSFILE"
        osascript -e "
            display notification \"Done — media key sent\"
            with title \"Play/Pause Key\"
            subtitle \"Countdown finished\"
        " 2>/dev/null
    fi
) &
disown

echo "Playing/Pausing in $DURATION  |  Status: run 'Timer Status'"
