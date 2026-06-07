# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development

```bash
# Build the CLI binary (single-file Swift, no dependencies)
swiftc -O -o media-pause main.swift

# Build the menu bar app
bash menu-bar/build.sh
open menu-bar/CountdownTimer.app

# Install locally for dev
ln -sf "$PWD/media-pause" ~/bin/media-pause
```

There is no test suite, package manager, or linting setup. The project is a single Swift file compiled with the system `swiftc`.

## Architecture

**Core binary** (`main.swift`): A single ~860-line Swift script using `#!/usr/bin/swift`. It imports Foundation and AppKit only — no Swift Package Manager, no external dependencies. The system `swiftc` toolchain is the only build requirement.

Key subsystems within `main.swift`:
- **Browser model** (lines 67–89): Defines supported Chromium-based browsers with their bundle IDs and AppleScript names. The `all` pseudo-browser expands to every defined browser.
- **Duration parser** (line 152): Accepts seconds (`3600`), human formats (`1h`, `30m`, `1h30m`, `2h15m30s`).
- **Browser actions** (lines 335–494): Each action (pause, resume, mute, quit, play/pause key) uses a different mechanism:
  - **Pause/Resume**: AppleScript → execute JavaScript in each browser tab. Uses `data-media-pause` DOM attributes to track which elements were paused, so resume can target only those.
  - **Mute**: AppleScript to set tab `muted` property via native browser API (no JS needed).
  - **Quit**: `NSWorkspace.shared.runningApplications` → `terminate()`.
  - **Play/Pause key**: dlopen + dlsym into `MediaRemote.framework` (private system framework) to call `MRMediaRemoteSendCommand(2, nil)` — the same API Control Center uses.
- **JS capability check** (line 281): Pre-flight AppleScript test to detect whether "Allow JavaScript from Apple Events" is enabled in the browser. Runs before pause/resume modes.
- **Countdown loop** (line 620): Terminal TUI with progress bar, spinner, color gradient (blue→yellow→red), and Space-key pause/resume (via raw stdin). Also writes PID and status files to `/tmp/` for external readers.
- **Terminal UI** (lines 187–268): TTY-aware ANSI rendering with box drawing, color gradients, and partial block characters for sub-character progress bar resolution. Gracefully degrades when stdout is not a TTY.

**Menu bar app** (`menu-bar/`): A SwiftUI `@main` app using `NSStatusItem` with a monospaced-digit countdown display. It reads timer state from `/tmp/media-pause.pid` and `/tmp/media-pause.status` files — polling every second. The PID file contains `"<pid> <instance_id>"`; the status file contains `"<start_ts> <total_sec> <mode> <label> <instance_id>"`. The menu bar app verifies the instance ID matches to avoid displaying stale data from a previous timer.

**Raycast integration** (`raycast/`): Shell scripts following Raycast's schema convention. Each command script sources `_media-pause-lib.sh` (a bash 3.2-compatible shared library). The library handles:
- Binary discovery (brew, /opt/homebrew, /usr/local, ~/bin)
- Browser detection by checking `/Applications/` and `~/Applications/`
- Browser preference memory via `~/.cache/media-pause/last-browser`
- Timer lifecycle: launches the core binary in background, writes PID/status files, spawns a background watcher that cleans up and sends a notification when the timer completes
- Instance ID mechanism to prevent stale watchers from nuking a new timer's PID/status files

**Homebrew tap** (`homebrew-tap/Formula/media-pause.rb`): Standard Homebrew formula. Compiles with `swiftc -O`, installs to bin, no runtime dependencies beyond macOS.

## Inter-process communication

The core binary, Raycast scripts, and menu bar app communicate through two temporary files:
- `/tmp/media-pause.pid` — `"<pid> <instance_id>"`
- `/tmp/media-pause.status` — `"<start_timestamp> <total_seconds> <mode> <label> <instance_id>"`

Only one timer can run at a time. Starting a new timer when one is running will fail with a message to stop the current timer first (`Timer Stop`).

## Important conventions

- Browser preference is remembered in `~/.cache/media-pause/last-browser` after the user explicitly chooses a browser, not after using the default.
- The `instance_id` mechanism (timestamp + PID combination) is critical — it prevents the background watcher process from cleaning up PID/status files that belong to a newer timer.
- All Raycast scripts use bash 3.2 (macOS default) — no associative arrays, no `readarray`/`mapfile`.
- The menu bar app is launched with `open -g` (background, no dock icon) and uses `LSUIElement = true` in Info.plist.
