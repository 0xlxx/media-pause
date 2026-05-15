#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Media Pause
# @raycast.mode compact
# @raycast.icon ⏸
# @raycast.packageName Media Tools
# @raycast.description Pause browser media after a countdown

# Optional parameters:
# @raycast.author bjorn
# @raycast.keywords timer pause media browser countdown

# Arguments:
# @raycast.argument1 { "type": "text", "placeholder": "Duration (30m, 1h, 3600)", "optional": true }
# @raycast.argument2 { "type": "text", "placeholder": "Browser: chrome, brave, all", "optional": true }

DURATION="${1:-1h}"
USER_INPUT="${2:-chrome}"

# ──────────────────────────────────────────────
# Locate the media-pause binary
# ──────────────────────────────────────────────
find_bin() {
    if command -v media-pause &>/dev/null; then
        echo "media-pause"
    elif [ -x "/opt/homebrew/bin/media-pause" ]; then
        echo "/opt/homebrew/bin/media-pause"
    elif [ -x "/usr/local/bin/media-pause" ]; then
        echo "/usr/local/bin/media-pause"
    elif [ -x "$HOME/bin/media-pause" ]; then
        echo "$HOME/bin/media-pause"
    else
        echo ""
    fi
}

BIN="$(find_bin)"
if [ -z "$BIN" ]; then
    echo "media-pause not found. Install: brew install bjorn/homebrew-tap/media-pause"
    exit 1
fi

# ──────────────────────────────────────────────
# Detect which browsers are actually installed
# ──────────────────────────────────────────────
is_installed() {
    local app_name="$1"
    [ -d "/Applications/$app_name" ] || [ -d "$HOME/Applications/$app_name" ] || \
    [ -d "/Applications/${app_name%.app}" ] || [ -d "$HOME/Applications/${app_name%.app}" ]
}

# Map browser key to .app name (bash 3.2 compatible)
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
# Resolve browser selection
# ──────────────────────────────────────────────
if [ "$USER_INPUT" = "all" ]; then
    BROWSERS="$INSTALLED"
    if [ -z "$BROWSERS" ]; then
        echo "No supported browsers detected. Install Chrome, Brave, Edge, etc."
        exit 1
    fi
else
    # Parse comma-separated input, filter to only installed
    IFS=',' read -ra KEYS <<< "$USER_INPUT"
    BROWSERS=""
    for key in "${KEYS[@]}"; do
        key=$(echo "$key" | xargs | tr '[:upper:]' '[:lower:]')
        if [ "$key" = "all" ]; then
            BROWSERS="$INSTALLED"
            break
        fi
        if echo "$INSTALLED" | grep -qw "$key"; then
            BROWSERS="$BROWSERS,$key"
        fi
    done
    BROWSERS="${BROWSERS#,}"
    if [ -z "$BROWSERS" ]; then
        echo "None of the requested browsers are installed."
        echo "Installed: ${INSTALLED:-none}"
        exit 1
    fi
fi

# ──────────────────────────────────────────────
# Format for display
# ──────────────────────────────────────────────
NUM_BROWSERS=$(echo "$BROWSERS" | tr ',' '\n' | wc -l | tr -d ' ')
BROWSER_LABEL=$(echo "$BROWSERS" | tr ',' ', ')

# ──────────────────────────────────────────────
# Run in background, notify on completion
# ──────────────────────────────────────────────
(
    # Post start notification
    osascript -e "display notification \"$DURATION countdown started for $BROWSER_LABEL\" with title \"media-pause\" subtitle \"Timer running\"" 2>/dev/null

    "$BIN" -b "$BROWSERS" "$DURATION" >/dev/null 2>&1
    EXIT=$?

    if [ $EXIT -eq 0 ]; then
        osascript -e "display notification \"Done — media paused on $BROWSER_LABEL\" with title \"media-pause\" subtitle \"Countdown finished\"" 2>/dev/null
    else
        osascript -e "display notification \"Cancelled or failed\" with title \"media-pause\" subtitle \"Countdown stopped\"" 2>/dev/null
    fi
) &
disown

echo "Started: $DURATION → $NUM_BROWSERS browser(s) ($BROWSER_LABEL)"
