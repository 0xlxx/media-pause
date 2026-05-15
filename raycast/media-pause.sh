#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Media Pause
# @raycast.mode silent
# @raycast.icon ⏸
# @raycast.packageName Media Tools
# @raycast.description Pause browser media after a countdown

# Optional parameters:
# @raycast.author bjorn
# @raycast.keywords timer pause media browser countdown

# Arguments:
# @raycast.argument1 { "type": "text", "placeholder": "Duration (e.g. 30m, 1h, 3600)", "optional": true }
# @raycast.argument2 { "type": "dropdown", "placeholder": "Browser", "optional": true, "data": [{"title": "Chrome", "value": "chrome"}, {"title": "Brave", "value": "brave"}, {"title": "Edge", "value": "edge"}, {"title": "Arc", "value": "arc"}, {"title": "Chromium", "value": "chromium"}, {"title": "Opera", "value": "opera"}, {"title": "Vivaldi", "value": "vivaldi"}, {"title": "All Browsers", "value": "all"}] }

DURATION="${1:-1h}"
BROWSER="${2:-chrome}"

# Locate the media-pause binary (brew install, manual install, or local build)
if command -v media-pause &>/dev/null; then
    BIN="media-pause"
elif [ -x "/opt/homebrew/bin/media-pause" ]; then
    BIN="/opt/homebrew/bin/media-pause"
elif [ -x "/usr/local/bin/media-pause" ]; then
    BIN="/usr/local/bin/media-pause"
elif [ -x "$HOME/bin/media-pause" ]; then
    BIN="$HOME/bin/media-pause"
else
    echo "media-pause not found. Install it with: brew install bjorn/homebrew-tap/media-pause"
    exit 1
fi

exec "$BIN" -b "$BROWSER" "$DURATION"
