#!/bin/bash
# Shared library for media-pause Raycast commands (bash 3.2 compatible)

CACHE_DIR="$HOME/.cache/media-pause"
PIDFILE="/tmp/media-pause.pid"
STATUSFILE="/tmp/media-pause.status"

# ── Binary discovery ──────────────────────────────────
INSTALL_HINT="media-pause not found. Install: brew install 0xlxx/homebrew-tap/media-pause"

find_bin() {
    command -v media-pause 2>/dev/null && return
    for p in /opt/homebrew/bin /usr/local/bin "$HOME/bin"; do
        [ -x "$p/media-pause" ] && echo "$p/media-pause" && return
    done
}

require_bin() {
    local bin=$(find_bin)
    if [ -z "$bin" ]; then
        echo "$INSTALL_HINT"
        exit 1
    fi
    echo "$bin"
}

# ── App name mapping (bash 3.2, no associative arrays) ──
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

is_installed() {
    [ -d "/Applications/$1" ] || [ -d "$HOME/Applications/$1" ]
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

# ── Browser resolution ────────────────────────────────
resolve_browsers() {
    local input="$1" installed="$2" result="" key
    [ "$input" = "all" ] && { echo "$installed"; return; }
    local old_ifs="$IFS"; IFS=','
    for key in $input; do
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')
        [ "$key" = "all" ] && { echo "$installed"; IFS="$old_ifs"; return; }
        if echo ",$installed," | grep -q ",$key,"; then
            result="$result,$key"
        fi
    done
    IFS="$old_ifs"
    echo "${result#,}"
}

# ── Browser memory ─────────────────────────────────────
remember_browser() {
    mkdir -p "$CACHE_DIR"
    echo "$1" > "$CACHE_DIR/last-browser"
}

recall_browser() {
    [ -f "$CACHE_DIR/last-browser" ] && cat "$CACHE_DIR/last-browser" || echo "chrome"
}

# ── Duration parsing (for status display) ──────────────
parse_duration_seconds() {
    local input="$1" total=0
    if echo "$input" | grep -qE '^[0-9]+$'; then
        echo "$input"
        return
    fi
    local h=$(echo "$input" | grep -oE '[0-9]+h' | sed 's/h//')
    local m=$(echo "$input" | grep -oE '[0-9]+m' | sed 's/m//')
    local s=$(echo "$input" | grep -oE '[0-9]+s' | sed 's/s//')
    [ -n "$h" ] && total=$((total + h * 3600))
    [ -n "$m" ] && total=$((total + m * 60))
    [ -n "$s" ] && total=$((total + s))
    echo "$total"
}

# ── Read current timer state ───────────────────────────
# Returns: "pid instance_id start_ts total_sec mode_label label"
read_current_timer() {
    if [ ! -f "$PIDFILE" ] || [ ! -f "$STATUSFILE" ]; then
        return 1
    fi
    local pid=$(cat "$PIDFILE" 2>/dev/null | awk '{print $1}')
    local iid=$(cat "$PIDFILE" 2>/dev/null | awk '{print $2}')
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
        rm -f "$PIDFILE" "$STATUSFILE"
        return 1
    fi
    # Verify it's actually media-pause (not a recycled PID matching another process)
    local pname=$(ps -p "$pid" -o comm= 2>/dev/null)
    if [ "$pname" != "media-pause" ]; then
        rm -f "$PIDFILE" "$STATUSFILE"
        return 1
    fi
    echo "$pid $iid"
    return 0
}

# ── Stop a running timer ──────────────────────────────
stop_timer() {
    local pid="$1"
    # Kill media-pause process and its children (the watcher)
    [ -n "$pid" ] && kill -TERM "$pid" 2>/dev/null
    # Give it a moment, then force
    sleep 0.3
    [ -n "$pid" ] && kill -KILL "$pid" 2>/dev/null
    rm -f "$PIDFILE" "$STATUSFILE"
}

# ── Menu bar app ───────────────────────────────────────
ensure_menubar() {
    # Already running?
    pgrep -f "CountdownTimer.app" >/dev/null 2>&1 && return
    local app_path=""
    for p in "$HOME/bin/CountdownTimer.app" \
             "$(cd "$DIR/../menu-bar" 2>/dev/null && pwd)/CountdownTimer.app" \
             "/usr/local/share/media-pause/CountdownTimer.app"; do
        [ -d "$p" ] && app_path="$p" && break
    done
    [ -z "$app_path" ] && return
    open -g "$app_path" 2>/dev/null &
}

# ── Core: launch timer ──────────────────────────────────
launch_timer() {
    local mode="$1" duration="$2" user_browser="$3" mode_flag="$4" mode_label="$5"

    local installed=$(detect_installed)
    local default_browser=$(recall_browser)

    # Resolve browser: user input > remembered default > chrome
    local input="${user_browser:-$default_browser}"
    [ -z "$input" ] && input="chrome"
    local browsers=$(resolve_browsers "$input" "$installed")

    if [ -z "$browsers" ]; then
        echo "No supported browser found. Installed: ${installed:-none}"
        exit 1
    fi

    # Remember for next time (only if user explicitly chose)
    if [ -n "$user_browser" ]; then
        remember_browser "$user_browser"
    fi

    local num=$(echo "$browsers" | tr ',' '\n' | wc -l | tr -d ' ')
    local label=$(echo "$browsers" | tr ',' ', ')
    local dur_sec=$(parse_duration_seconds "$duration")
    local bin=$(require_bin)

    # ── Prevent duplicate timers ──────────────────────
    local current=$(read_current_timer)
    if [ -n "$current" ]; then
        local old_meta=$(cat "$STATUSFILE" 2>/dev/null)
        local old_mode=$(echo "$old_meta" | awk '{print $3}')
        local old_label=$(echo "$old_meta" | awk '{for(i=4;i<=NF-1;i++) printf "%s%s", $i, (i<NF-1?" ":"")}')
        local old_start=$(echo "$old_meta" | awk '{print $1}')
        local old_total=$(echo "$old_meta" | awk '{print $2}')
        local old_elapsed=0
        [ -n "$old_start" ] && old_elapsed=$(($(date +%s) - old_start))
        local old_remain=$((old_total - old_elapsed))
        [ $old_remain -lt 0 ] && old_remain=0
        local old_fmt=$(printf "%02d:%02d" $((old_remain/60)) $((old_remain%60)))

        echo "Timer already running: $old_mode · $old_label · ${old_fmt}m remaining"
        echo "Stop it first: run 'Timer Stop'"
        exit 1
    fi

    # ── Ensure menu bar app is running ───────────────────
    ensure_menubar

    # ── Launch ──────────────────────────────────────────
    "$bin" $mode_flag -b "$browsers" "$duration" >/dev/null 2>&1 &
    local pid=$!
    local instance_id="$(date +%s).$$"

    # Write PID with instance ID so watcher can verify ownership
    echo "$pid $instance_id" > "$PIDFILE"
    echo "$(date +%s) $dur_sec $mode_label $label $instance_id" > "$STATUSFILE"

    osascript -e "
        display notification \"$duration countdown started for $label\"
        with title \"media-pause — $mode_label\"
        subtitle \"Timer running\"
    " 2>/dev/null

    # Background watcher: poll until PID exits, then notify & cleanup
    # Uses instance_id to prevent stale watchers from nuking new timer files
    (
        while kill -0 "$pid" 2>/dev/null; do sleep 1; done
        # Only cleanup if this instance is still the active one
        cur_iid=""
        [ -f "$PIDFILE" ] && cur_iid=$(cat "$PIDFILE" 2>/dev/null | awk '{print $2}')
        if [ "$cur_iid" = "$instance_id" ]; then
            rm -f "$PIDFILE" "$STATUSFILE"
            osascript -e "
                display notification \"Done — media action completed for $label\"
                with title \"media-pause — $mode_label\"
                subtitle \"Countdown finished\"
            " 2>/dev/null
        fi
    ) &
    disown

    echo "$mode_label $label in $duration  |  Status: run 'Timer Status'"
}

# ── Status: progress display ───────────────────────────
show_status() {
    if [ ! -f "$PIDFILE" ] || [ ! -f "$STATUSFILE" ]; then
        echo "No media-pause timer is running."
        return
    fi

    local pid=$(cat "$PIDFILE" 2>/dev/null | awk '{print $1}')
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
        rm -f "$PIDFILE" "$STATUSFILE"
        echo "No media-pause timer is running."
        return
    fi
    local pname=$(ps -p "$pid" -o comm= 2>/dev/null)
    if [ "$pname" != "media-pause" ]; then
        rm -f "$PIDFILE" "$STATUSFILE"
        echo "No media-pause timer is running."
        return
    fi

    # Parse metadata
    local meta=$(cat "$STATUSFILE")
    local start_ts=$(echo "$meta" | awk '{print $1}')
    local total_sec=$(echo "$meta" | awk '{print $2}')
    local mode_label=$(echo "$meta" | awk '{print $3}')
    local label=$(echo "$meta" | awk '{for(i=4;i<=NF-1;i++) printf "%s%s", $i, (i<NF-1?" ":"")}')

    local now=$(date +%s)
    local elapsed=$((now - start_ts))
    local remaining=$((total_sec - elapsed))
    [ $remaining -lt 0 ] && remaining=0

    # Format times
    local fmt_elapsed=$(printf "%02d:%02d:%02d" $((elapsed/3600)) $(((elapsed%3600)/60)) $((elapsed%60)))
    local fmt_remain=$(printf "%02d:%02d:%02d" $((remaining/3600)) $(((remaining%3600)/60)) $((remaining%60)))
    local pct=0
    [ "$total_sec" -gt 0 ] && pct=$(( elapsed * 100 / total_sec ))
    [ $pct -gt 100 ] && pct=100

    # Progress bar
    local bar_w=20
    local filled=$(( pct * bar_w / 100 ))
    local empty=$(( bar_w - filled ))
    local bar=$(printf "%${filled}s" | sed 's/ /█/g')$(printf "%${empty}s" | sed 's/ /░/g')

    echo "$mode_label · $label"
    echo "$bar ${pct}%"
    echo "Stop: run 'Timer Stop'"
    echo "⏳ $fmt_remain remaining   ⏱ $fmt_elapsed elapsed"
}
