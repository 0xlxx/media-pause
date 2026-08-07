# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development

```bash
# Build the CLI binary (SwiftPM, zero external dependencies)
swift build -c release --product media-pause
ln -sf "$PWD/.build/release/media-pause" ~/bin/media-pause

# Run unit tests (88 tests, custom lightweight framework — no XCTest needed)
swift run media-pause-tests

# Compilation test + smoke test
bash scripts/verify.sh

# Mutation testing (one run ~1-2 min; consumes resources — use sparingly)
python3 scripts/mutate.py

# Build the menu bar app
bash menu-bar/build.sh
open menu-bar/CountdownTimer.app
```

Requires macOS Swift toolchain (SwiftPM). Works with **Command Line Tools only** — there is no Xcode/XCTest dependency.

## Architecture (v4.0)

**SwiftPM package** with three targets:

- `MediaPauseCore` (`Sources/MediaPauseCore/`) — all logic, designed for testability:
  - **Pure logic** (unit-tested): `Duration.swift`, `Arguments.swift`, `Browser.swift`, `MediaJS.swift`, `IPC.swift`, `CountdownTimer.swift`, `CDPChannel.swift` (protocol helpers), `Report.swift`, `Setup.swift` (Preferences editing).
  - **Channels** behind small protocols so tests inject fakes:
    - `ProcessRunning` (`AppleScriptChannel.swift`, `MuteChannel.swift`) — osascript execution.
    - `CDPTransport` (`CDPChannel.swift`) — target discovery + Runtime.evaluate.
    - `Clock` (`CountdownTimer.swift`) — injectable time source.
    - `MediaEngine` (`Channels.swift`) — runs channels in priority order; fallback channel only fires when everything before it failed; appends an honest failure result when nothing succeeded.
- `media-pause` (`Sources/media-pause/`) — thin executable layer: TUI, channel factory (CDP probe → AppleScript → media key), orchestration, status/stop/setup, `URLSessionCDPTransport`.
- `media-pause-tests` (`Tests/MediaPauseCoreTests/`) — custom assertion framework (`TestKit.swift`) + `main.swift` test registry. Run with `swift run media-pause-tests`.

**Channel priority** (per pause/resume action): CDP (if a Chrome debug port is reachable) → AppleScript JS injection → media key (CGEvent to PID) → system media key (MediaRemote, only when a Now Playing session exists).

## Important conventions

- **Keep Core AppKit-free where possible.** `MediaKeyChannel.swift` currently imports AppKit/CoreGraphics; everything else should stay pure Foundation so logic is unit-testable without a GUI. Channels receive platform hooks via closures (e.g. `instances: () -> [NSRunningApplication]`, `activate: () -> Void`).
- **JS expressions must stay AppleScript-embeddable**: no double quotes, no newlines (`MediaJS.isAppleScriptEmbeddable` guards this in tests).
- **AppleScript if/else must be multi-line** in `AppleScriptScripts.actionScript` — one-line `if … then … else` fails to compile when the else clause contains `&` concatenation.
- **IPC format is stable** (`/tmp/media-pause.pid`, `/tmp/media-pause.status`): menu bar app and Raycast depend on it. See `IPC.swift` for the wire format. `instanceID` (last field) prevents stale watchers from touching a newer timer.
- **Automation instances must be quit before JS injection.** With multiple Chrome instances (e.g. a `chrome-devtools-mcp` instance), AppleScript always routes to the automation instance (no windows) and JS injection silently fails (`-1719`). `quitAutomationInstances(of:)` in `Run.swift` terminates them before the JS channel runs; `AutomationArgs.isAutomation` (Core, unit-tested) detects them.
- **No SIGSTOP freezing** — it corrupts Chrome's media pipeline. Do not reintroduce it.
- **Mutation testing is expensive** (~1-2 min per run, rebuilds in a temp workspace). Run only when the test suite changes; verify.sh is the cheap gate.
- The `media-pause` executable target uses `main.swift` as its entry point; Core has no top-level code.
