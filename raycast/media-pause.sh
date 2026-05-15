#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Media Pause
# @raycast.mode compact
# @raycast.icon ⏸
# @raycast.packageName Media Tools
# @raycast.description Countdown timer to pause/resume/mute browser media

# Optional parameters:
# @raycast.author bjorn
# @raycast.keywords timer pause resume mute quit browser countdown

# Arguments:
# @raycast.argument1 { "type": "text", "placeholder": "Duration (30m, 1h, 3600) — default 1h", "optional": true }
# @raycast.argument2 { "type": "text", "placeholder": "Browser: chrome, brave, all — default chrome", "optional": true }
# @raycast.argument3 { "type": "dropdown", "placeholder": "Mode — default Pause", "optional": true, "data": [{"title": "Pause (default)", "value": "pause"}, {"title": "Resume", "value": "resume"}, {"title": "Mute", "value": "mute"}, {"title": "Quit Browser", "value": "quit"}, {"title": "Play/Pause Key", "value": "playpause"}] }

DURATION="${1:-1h}"
USER_INPUT="${2:-chrome}"
MODE="${3:-pause}"

PIDFILE="/tmp/media-pause.pid"

# ──────────────────────────────────────────────
# Locate binary
# ──────────────────────────────────────────────
find_bin() {
    command -v media-pause 2>/dev/null && return
    for p in /opt/homebrew/bin /usr/local/bin "$HOME/bin"; do
        [ -x "$p/media-pause" ] && echo "$p/media-pause" && return
    done
}
BIN="$(find_bin)"
if [ -z "$BIN" ]; then
    echo "media-pause not found. Install: brew install bjorn/homebrew-tap/media-pause"
    exit 1
fi

# ──────────────────────────────────────────────
# Detect installed browsers
# ──────────────────────────────────────────────
is_installed() {
    local app_name="$1"
    [ -d "/Applications/$app_name" ] || [ -d "$HOME/Applications/$app_name" ]
}

app_name() {
    case "$1" in
        chrome)   echo "Google Chrome.app" ;;
        brave)    echo "Brave Browser.app" ;;
        edge)     echo "Microsoft Edge.app" ;;
        arc)      echo "Arc.app" ;;
        chromium) echo "Chromium.app" ;;
        opera)    echo "Opera.app" ;;
        vivaldi)  echo "Vivaldi.app" ;;
        *)        echo "" ;;
    esac
}

detect_installed() {
    local found=""
    for key in chrome brave edge arc chromium opera vivaldi; do
        if is_installed "$(app_name "$key")"; then
            found="$found,$key"
        fi
    done
    echo "${found#,}"
}

INSTALLED=$(detect_installed)

# ──────────────────────────────────────────────
# Resolve browser
# ──────────────────────────────────────────────
resolve_browsers() {
    local input="$1"
    local result=""

    # "all" → all installed
    if [ "$input" = "all" ]; then
        echo "$INSTALLED"
        return
    fi

    # Comma-separated, filter to installed
    local old_ifs="$IFS"
    IFS=','
    for key in $input; do
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')
        [ "$key" = "all" ] && { echo "$INSTALLED"; return; }
        if echo ",$INSTALLED," | grep -q ",$key,"; then
            result="$result,$key"
        fi
    done
    IFS="$old_ifs"
    echo "${result#,}"
}

BROWSERS=$(resolve_browsers "$USER_INPUT")
if [ -z "$BROWSERS" ]; then
    echo "No supported browser found. Installed: ${INSTALLED:-none}"
    exit 1
fi

NUM=$(echo "$BROWSERS" | tr ',' '\n' | wc -l | tr -d ' ')
LABEL=$(echo "$BROWSERS" | tr ',' ', ')

# ──────────────────────────────────────────────
# Build command
# ──────────────────────────────────────────────
MODE_FLAG=""
MODE_LABEL="Pause"
case "$MODE" in
    resume)    MODE_FLAG="-r"; MODE_LABEL="Resume" ;;
    mute)      MODE_FLAG="-m"; MODE_LABEL="Mute" ;;
    quit)      MODE_FLAG="-q"; MODE_LABEL="Quit" ;;
    playpause) MODE_FLAG="-p"; MODE_LABEL="Play/Pause" ;;
    *)         MODE_FLAG="";   MODE_LABEL="Pause" ;;
esac

# ──────────────────────────────────────────────
# Run in background, notify on completion
# ──────────────────────────────────────────────

# Launch media-pause in background, capture real PID
"$BIN" $MODE_FLAG -b "$BROWSERS" "$DURATION" >/dev/null 2>&1 &
PID=$!
echo "$PID" > "$PIDFILE"

osascript -e "
    display notification \"$DURATION countdown started for $LABEL\"
    with title \"media-pause — $MODE_LABEL\"
    subtitle \"Timer running\"
" 2>/dev/null

# Background watcher: poll until PID exits, then notify
(
    while kill -0 "$PID" 2>/dev/null; do
        sleep 1
    done
    rm -f "$PIDFILE"
    osascript -e "
        display notification \"Done — media action completed for $LABEL\"
        with title \"media-pause — $MODE_LABEL\"
        subtitle \"Countdown finished\"
    " 2>/dev/null
) &
disown

echo "$MODE_LABEL: $DURATION → $NUM browser(s) ($LABEL)  |  Status: run 'Media Pause Status'"
