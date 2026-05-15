#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$DIR/CountdownTimer.app"
BIN_DIR="$APP_DIR/Contents/MacOS"
mkdir -p "$BIN_DIR"

swiftc -O -parse-as-library \
    -o "$BIN_DIR/CountdownTimer" \
    "$DIR/CountdownTimer.swift" \
    -framework SwiftUI \
    -framework AppKit

# Minimal Info.plist so macOS treats it as a proper app (no dock icon)
cat > "$APP_DIR/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>CountdownTimer</string>
    <key>CFBundleIdentifier</key>
    <string>dev.bjorn.media-pause.CountdownTimer</string>
    <key>CFBundleName</key>
    <string>CountdownTimer</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

echo "Built: $APP_DIR"
echo "Run: open '$APP_DIR'"
