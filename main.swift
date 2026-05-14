#!/usr/bin/swift

import Foundation
import AppKit

// MARK: - Constants

let VERSION = "3.0.0"

let TICK_US: UInt32 = 33_000  // ~30fps smooth animation
let PARTIAL_BLOCKS = ["", "▏", "▎", "▍", "▌", "▋", "▊", "▉"]
let SPINNER = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]

// Detect whether stdout is a terminal (TTY).
let isTTY = isatty(STDOUT_FILENO) == 1

// ANSI escape sequences (no-op when not a TTY)
func ansi(_ code: String) -> String { isTTY ? "\u{001B}[\(code)" : "" }
func hideCursor()  -> String { ansi("?25l") }
func showCursor()  -> String { ansi("?25h") }
func clearScreen() -> String { ansi("2J") }
func cursorHome()  -> String { ansi("H") }

func rgb(_ r: Int, _ g: Int, _ b: Int) -> String { isTTY ? "\u{001B}[38;2;\(r);\(g);\(b)m" : "" }
func fgReset()   -> String { isTTY ? "\u{001B}[0m" : "" }
func fgBold()    -> String { isTTY ? "\u{001B}[1m" : "" }

// MARK: - Global

var running = true
var lastHotkeyTime: Double = 0

func setupSignals() {
    signal(SIGINT)  { _ in running = false }
    signal(SIGTERM) { _ in running = false }
    signal(SIGQUIT) { _ in running = false }
    signal(SIGWINCH, SIG_IGN)
}

// MARK: - Stdin Key Watch (for Space hotkey during countdown)

var originalTermios = termios()

func enableRawStdin() -> Bool {
    guard isatty(STDIN_FILENO) == 1 else { return false }
    tcgetattr(STDIN_FILENO, &originalTermios)
    var raw = originalTermios
    raw.c_lflag &= ~UInt(ICANON | ECHO)
    raw.c_cc.0 = 0  // VMIN: return immediately
    raw.c_cc.1 = 0  // VTIME: no timeout
    tcsetattr(STDIN_FILENO, TCSANOW, &raw)
    _ = fcntl(STDIN_FILENO, F_SETFL, O_NONBLOCK)
    return true
}

func restoreStdin() {
    tcsetattr(STDIN_FILENO, TCSANOW, &originalTermios)
}

func checkSpaceKey() -> Bool {
    var buf = [UInt8](repeating: 0, count: 1)
    let n = read(STDIN_FILENO, &buf, 1)
    return n == 1 && buf[0] == 0x20 // space
}

// MARK: - Browser Definition

struct Browser {
    let key: String           // CLI flag value: "chrome", "brave", etc.
    let displayName: String   // Human-readable: "Google Chrome"
    let appleScriptName: String  // tell application "..."
    let bundleID: String      // com.google.Chrome, etc.

    static let all: [Browser] = [
        Browser(key: "chrome",   displayName: "Chrome",   appleScriptName: "Google Chrome",       bundleID: "com.google.Chrome"),
        Browser(key: "brave",    displayName: "Brave",    appleScriptName: "Brave Browser",        bundleID: "com.brave.Browser"),
        Browser(key: "edge",     displayName: "Edge",     appleScriptName: "Microsoft Edge",       bundleID: "com.microsoft.edgemac"),
        Browser(key: "arc",      displayName: "Arc",      appleScriptName: "Arc",                  bundleID: "company.thebrowser.Browser"),
        Browser(key: "chromium", displayName: "Chromium", appleScriptName: "Chromium",             bundleID: "org.chromium.Chromium"),
        Browser(key: "opera",    displayName: "Opera",    appleScriptName: "Opera",                bundleID: "com.operasoftware.Opera"),
        Browser(key: "vivaldi",  displayName: "Vivaldi",  appleScriptName: "Vivaldi",              bundleID: "com.vivaldi.Vivaldi"),
    ]

    static func byKey(_ key: String) -> Browser? {
        all.first { $0.key == key }
    }
}

// Current browser (set during argument parsing)
var browser = Browser.byKey("chrome")!

// MARK: - Version & Help

func showVersion() {
    print("media-pause \(VERSION)")
    exit(0)
}

func showHelp() {
    let name = CommandLine.arguments[0].split(separator: "/").last ?? "media-pause"
    let browserList = Browser.all.map { "            \($0.key) — \($0.displayName)" }.joined(separator: "\n")
    print("""
        Usage: \(name) [options] [duration]

        Modes:
          (default)     Pause media on all browser tabs after countdown
          -r, --resume  Resume (play) media on browser tabs
          -p, --playpause  Send system media play/pause key (works with ANY app)
          -m, --mute    Mute only audible browser tabs after countdown
          -q, --quit    Quit the browser entirely after countdown

        Options:
          -b, --browser <name>  Target browser for tab actions (default: chrome)
          -h, --help            Show this help
          -V, --version         Show version

        Supported browsers (for tab actions):
        \(browserList)

        Duration Formats:
          3600          Seconds
          1h            Hours
          30m           Minutes
          1h30m         Combined

        Examples:
          \(name) 45m              Pause browser media after 45 minutes
          \(name) -p 30m           Send play/pause key after 30 minutes (any app)
          \(name) -r               Resume previously paused browser media
          \(name) -r 10s           Resume, play for 10 seconds, then pause again
          \(name) -b brave 30m     Pause Brave browser media after 30 minutes
          \(name) -b edge -q 1h    Quit Edge after 1 hour
          \(name) -m 1h            Mute audible tabs after 1 hour

        Prerequisite (pause/resume/mute modes):
          In the browser: View > Developer > Allow JavaScript from Apple Events

        The -p/--playpause mode sends the macOS media key and works
        universally: browsers, Spotify, Apple Music, IINA, VLC, etc.

        During countdown: Space to pause/resume timer & media, Ctrl+C to cancel.
        """)
    exit(0)
}

// MARK: - Duration Parser

func parseDuration(_ input: String) -> Int {
    if let s = Int(input) {
        guard s > 0 else {
            fputs("Error: Duration must be positive\n", stderr)
            exit(1)
        }
        return s
    }

    var total = 0
    var matched = false
    var rem = input

    for (suffix, mult) in [("h", 3600), ("m", 60), ("s", 1)] {
        guard let r = rem.range(of: #"^(\d+)\#(suffix)"#, options: .regularExpression) else { continue }
        total += (Int(rem[r].dropLast()) ?? 0) * mult
        rem.removeSubrange(r)
        matched = true
    }

    guard matched, total > 0, rem.isEmpty else {
        fputs("Error: Invalid duration '\(input)'\n  Valid: 3600 | 1h | 30m | 1h30m | 2h15m30s\n", stderr)
        exit(1)
    }
    return total
}

// MARK: - Formatting

func formatHMS(_ s: Int) -> String {
    String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
}

// MARK: - Color Gradient (blue -> yellow -> red)

func gradientColor(_ t: Double) -> String {
    let t = max(0, min(1, t))
    let r: Int, g: Int, b: Int
    if t > 0.6 {
        let s = (1.0 - t) / 0.4
        r = Int(99  + s * 135); g = Int(179); b = Int(237 - s * 172)
    } else if t > 0.3 {
        let s = (0.6 - t) / 0.3
        r = Int(234 + s * 15); g = Int(179 - s * 64); b = Int(65 - s * 33)
    } else {
        let s = (0.3 - t) / 0.3
        r = Int(249 + s * 6); g = Int(115 - s * 115); b = Int(32 - s * 32)
    }
    return rgb(r, g, b)
}

// MARK: - Progress Bar

func buildBar(progress: Double, width: Int) -> String {
    let filled = progress * Double(width)
    let full = Int(filled)
    let pi = Int((filled - Double(full)) * 8)
    let partial = (pi > 0 && pi < 8) ? PARTIAL_BLOCKS[pi] : ""
    let empty = width - full - (partial.isEmpty ? 0 : 1)
    return String(repeating: "█", count: full) + partial + String(repeating: "░", count: max(0, empty))
}

// MARK: - Terminal Display Width

func displayWidth(_ s: String) -> Int {
    var w = 0
    for scalar in s.unicodeScalars {
        switch scalar.value {
        case 0x1F000...0x1FFFF, 0x2600...0x27BF, 0x2300...0x23FF:
            w += 2
        default:
            w += 1
        }
    }
    return w
}

// MARK: - Box Drawing

func drawBox(width: Int, lines: [String]) -> String {
    guard isTTY else {
        let inner = width - 2
        let ruler = String(repeating: "-", count: inner)
        var out = "/" + ruler + "\\\n"
        for (i, line) in lines.enumerated() {
            let plain = line.replacingOccurrences(of: "\u{001B}\\[[0-9;]*m", with: "", options: .regularExpression)
            let pad = max(0, width - 2 - plain.count)
            let pl = pad / 2; let pr = pad - pl
            if i == 1 && lines.count > 2 { out += "|" + ruler + "|\n" }
            out += "|" + String(repeating: " ", count: pl) + plain + String(repeating: " ", count: pr) + "|\n"
        }
        out += "\\" + ruler + "/"
        return out
    }

    let inner = max(2, width - 2)
    var out = "╭" + String(repeating: "─", count: inner) + "╮\n"
    for (i, line) in lines.enumerated() {
        let plain = line.replacingOccurrences(of: "\u{001B}\\[[0-9;]*m", with: "", options: .regularExpression)
        let lineW = displayWidth(plain)
        let pad = max(0, inner - lineW)
        let pl = pad / 2; let pr = pad - pl
        let padded = String(repeating: " ", count: pl) + line + String(repeating: " ", count: pr)
        if i == 1 { out += "├" + String(repeating: "─", count: inner) + "┤\n" }
        out += "│" + padded + "│\n"
    }
    out += "╰" + String(repeating: "─", count: inner) + "╯"
    return out
}

// MARK: - App Nap Prevention

func preventAppNap() -> NSObjectProtocol? {
    ProcessInfo.processInfo.beginActivity(
        options: [.userInitiated, .idleSystemSleepDisabled],
        reason: "media-pause countdown timer"
    )
}

// MARK: - Browser JS Capability Check

func checkBrowserJSCapability() -> String? {
    let script = """
    tell application "\(browser.appleScriptName)"
        if (count of windows) = 0 then return "OK"
        try
            execute (tab 1 of window 1) javascript "true"
            return "OK"
        on error errMsg
            return errMsg
        end try
    end tell
    """

    guard let appleScript = NSAppleScript(source: script) else {
        return "Internal error: could not create AppleScript"
    }
    var error: NSDictionary?
    let result = appleScript.executeAndReturnError(&error).stringValue ?? ""

    if result == "OK" { return nil }

    if result.contains("JavaScript") || result.contains("AppleScript") || result.contains("Apple Events") {
        return """
            \(browser.displayName)'s "Allow JavaScript from Apple Events" is disabled.

            To enable it in \(browser.displayName):
              View > Developer > Allow JavaScript from Apple Events

            Then run media-pause again.
            """
    }

    return result.isEmpty ? nil : result
}

// MARK: - ActionResult

struct ActionResult {
    let affected: Int
    let total: Int
    let tabs: [String]
    let error: String?
    let jsDisabled: Bool
}

// MARK: - Browser Actions (via AppleScript + JS injection)

func makeAppleScript(js: String) -> String {
    let escapedJS = js
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    return """
    tell application "\(browser.appleScriptName)"
        set okCount to 0
        set failCount to 0
        set totalTabs to 0
        set tabTitles to {}
        set lastErr to ""
        set allSameErr to true
        if (count of windows) = 0 then
            return {0, 0, {}, "", false, false}
        end if
        repeat with w in windows
            try
                set windowTabs to tabs of w
                repeat with t in windowTabs
                    set totalTabs to totalTabs + 1
                    try
                        execute t javascript "\(escapedJS)"
                        set okCount to okCount + 1
                        set allSameErr to false
                        try
                            set end of tabTitles to title of t
                        end try
                    on error e
                        set failCount to failCount + 1
                        if lastErr = "" then set lastErr to e
                        if lastErr is not equal to e then set allSameErr to false
                    end try
                end repeat
            end try
        end repeat
        return {okCount, totalTabs, tabTitles, lastErr, failCount, allSameErr}
    end tell
    """
}

func executeScript(_ script: String) -> ActionResult {
    guard let appleScript = NSAppleScript(source: script) else {
        return ActionResult(affected: 0, total: 0, tabs: [], error: "Internal error: could not create AppleScript", jsDisabled: false)
    }
    var error: NSDictionary?
    let result = appleScript.executeAndReturnError(&error)

    if let error = error {
        let msg = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
        return ActionResult(affected: 0, total: 0, tabs: [], error: msg, jsDisabled: false)
    }

    let affected  = Int(result.atIndex(1)?.int32Value ?? 0)
    let total     = Int(result.atIndex(2)?.int32Value ?? 0)

    var titles: [String] = []
    if let list = result.atIndex(3), list.numberOfItems > 0 {
        for i in 1...list.numberOfItems {
            titles.append(list.atIndex(i)?.stringValue ?? "")
        }
    }

    let errStr = result.atIndex(4)?.stringValue
    let err: String? = (errStr?.isEmpty ?? true) ? nil : errStr
    let failCount = Int(result.atIndex(5)?.int32Value ?? 0)
    let allSameErr = result.atIndex(6)?.booleanValue ?? false

    let isJSDisabled = (failCount > 0 && affected == 0 && allSameErr &&
                        (err?.contains("JavaScript") == true ||
                         err?.contains("AppleScript") == true ||
                         err?.contains("Apple Events") == true))

    return ActionResult(affected: affected, total: total, tabs: titles,
                        error: err, jsDisabled: isJSDisabled)
}

func pauseMedia() -> ActionResult {
    let js = "document.querySelectorAll('video,audio').forEach(function(e){try{e.pause()}catch(_){}});document.querySelectorAll('iframe').forEach(function(f){try{f.contentDocument.querySelectorAll('video,audio').forEach(function(e){try{e.pause()}catch(_){}})}catch(_){}})"
    return executeScript(makeAppleScript(js: js))
}

func resumeMedia() -> ActionResult {
    let js = "document.querySelectorAll('video,audio').forEach(function(e){try{e.play()}catch(_){}});document.querySelectorAll('iframe').forEach(function(f){try{f.contentDocument.querySelectorAll('video,audio').forEach(function(e){try{e.play()}catch(_){}})}catch(_){}})"
    return executeScript(makeAppleScript(js: js))
}

func muteAudibleTabs() -> ActionResult {
    let script = """
    tell application "\(browser.appleScriptName)"
        set okCount to 0
        set totalTabs to 0
        set tabTitles to {}
        if (count of windows) = 0 then
            return {0, 0, {}, "", false, false}
        end if
        repeat with w in windows
            try
                set windowTabs to tabs of w
                repeat with t in windowTabs
                    set totalTabs to totalTabs + 1
                    try
                        if audible of t then
                            set muted of t to true
                            set okCount to okCount + 1
                            try
                                set end of tabTitles to title of t
                            end try
                        end if
                    end try
                end repeat
            end try
        end repeat
        return {okCount, totalTabs, tabTitles, "", 0, false}
    end tell
    """

    let appleScript = NSAppleScript(source: script)
    var error: NSDictionary?
    let result = appleScript?.executeAndReturnError(&error)

    if let error = error {
        let msg = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
        return ActionResult(affected: 0, total: 0, tabs: [], error: msg, jsDisabled: false)
    }

    let affected  = Int(result?.atIndex(1)?.int32Value ?? 0)
    let total     = Int(result?.atIndex(2)?.int32Value ?? 0)

    var titles: [String] = []
    if let list = result?.atIndex(3), list.numberOfItems > 0 {
        for i in 1...list.numberOfItems {
            titles.append(list.atIndex(i)?.stringValue ?? "")
        }
    }

    return ActionResult(affected: affected, total: total, tabs: titles, error: nil, jsDisabled: false)
}

func quitBrowser() -> Bool {
    NSWorkspace.shared.runningApplications
        .first { $0.bundleIdentifier == browser.bundleID }?
        .terminate() ?? false
}

// MARK: - System Media Key (MediaRemote private framework — same API as Control Center)

typealias MRMediaRemoteSendCommandFunc = @convention(c) (UInt32, AnyObject?) -> Bool

func sendMediaPlayPause() -> Bool {
    guard let handle = dlopen(
        "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
        RTLD_NOW
    ) else { return false }

    guard let sym = dlsym(handle, "MRMediaRemoteSendCommand") else { return false }

    let MRMediaRemoteSendCommand = unsafeBitCast(sym, to: MRMediaRemoteSendCommandFunc.self)
    // kMRTogglePlayPause = 2
    return MRMediaRemoteSendCommand(2, nil)
}

// MARK: - Main

func main() {
    let args = CommandLine.arguments.dropFirst()
    var mode = "pause"
    var durStr: String? = nil   // nil = use default; set = user-provided

    var i = args.startIndex
    while i < args.endIndex {
        let arg = args[i]
        switch arg {
        case "-h", "--help":    showHelp()
        case "-V", "--version": showVersion()
        case "-r", "--resume":  mode = "resume"
        case "-p", "--playpause": mode = "playpause"
        case "-m", "--mute":    mode = "mute"
        case "-q", "--quit":    mode = "quit"
        case "-b", "--browser":
            i = args.index(after: i)
            if i < args.endIndex {
                let key = args[i].lowercased()
                guard let b = Browser.byKey(key) else {
                    fputs("Error: Unknown browser '\(args[i])'\n  Valid: \(Browser.all.map(\.key).joined(separator: ", "))\n", stderr)
                    exit(1)
                }
                browser = b
            } else {
                fputs("Error: -b requires a browser name\n", stderr)
                exit(1)
            }
        default:
            durStr = arg
        }
        i = args.index(after: i)
    }

    // --- Resume mode ---
    if mode == "resume" {
        if let dur = durStr {
            // Resume immediately, then count down to pause
            let totalSeconds = parseDuration(dur)
            let resumeResult = resumeMedia()
            // Show quick result unless it failed
            if resumeResult.jsDisabled || resumeResult.error != nil {
                print(hideCursor(), terminator: "")
                print(clearScreen() + cursorHome(), terminator: "")
                showResult(result: resumeResult, boxW: 62, icon: "▶", label: "Resume Media", verb: "Resumed")
                print(showCursor(), terminator: "")
                fflush(stdout)
                exit(resumeResult.jsDisabled || resumeResult.error != nil ? 1 : 0)
            }
            // Run the countdown, then pause
            runTimer(totalSeconds: totalSeconds, mode: "pause")
        } else {
            // Just resume, no timer
            print(hideCursor(), terminator: "")
            print(clearScreen() + cursorHome(), terminator: "")
            let box = drawBox(width: 62, lines: [
                "\(fgBold())▶  Resuming media on all \(browser.displayName) tabs...\(fgReset())",
                "",
                "\(rgb(140, 200, 255))Calling .play() on video/audio elements\(fgReset())",
            ])
            print(box)
            fflush(stdout)
            let result = resumeMedia()
            showResult(result: result, boxW: 62, icon: "▶", label: "Resume Media", verb: "Resumed")
            print("")
            print(showCursor(), terminator: "")
            fflush(stdout)
        }
        return
    }

    // --- All other modes require a duration ---
    let totalSeconds = parseDuration(durStr ?? "1h")

    // JS capability pre-flight (only for modes that inject JavaScript)
    if mode == "pause" || mode == "resume" {
        if let capErr = checkBrowserJSCapability() {
            print(hideCursor(), terminator: "")
            print(clearScreen() + cursorHome(), terminator: "")
            let msg = drawBox(width: 62, lines: [
                "\(fgBold())⚠  media-pause: Setup Required\(fgReset())",
                "",
                "\(rgb(255, 180, 50))\(capErr)\(fgReset())",
            ])
            print(msg)
            print("")
            print(showCursor(), terminator: "")
            fflush(stdout)
            exit(1)
        }
    }

    runTimer(totalSeconds: totalSeconds, mode: mode)
}

// MARK: - Timer

func runTimer(totalSeconds: Int, mode: String) {
    setupSignals()

    let activity = preventAppNap()
    defer { _ = activity }

    lastHotkeyTime = 0
    let stdinEnabled = enableRawStdin()
    defer {
        if stdinEnabled { restoreStdin() }
        print(showCursor(), terminator: "")
        fflush(stdout)
    }

    var ws = winsize()
    if !isTTY || ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &ws) != 0 || ws.ws_col == 0 {
        ws.ws_col = 80
    }
    let termW = Int(ws.ws_col)
    let boxW = max(20, min(termW, 64))
    let barW = max(1, boxW - 12)

    print(hideCursor(), terminator: "")
    print(clearScreen() + cursorHome(), terminator: "")

    let start = Date()
    var si = 0

    let actionLabel: String
    switch mode {
    case "mute":      actionLabel = "Muting audible tabs when done"
    case "quit":      actionLabel = "Quitting \(browser.displayName) when done"
    case "playpause": actionLabel = "Sending play/pause media key when done"
    default:          actionLabel = "Pausing media on all tabs when done"
    }

    if !isTTY {
        print("media-pause [\(browser.displayName)]: \(actionLabel.lowercased()) in \(formatHMS(totalSeconds))")
    }

    // --- Countdown Loop (with pause/resume via Space) ---
    var isTimerPaused = false
    var totalPaused: Double = 0
    var pausedAt: Date? = nil

    let spaceCooldown: Double = 0.3  // prevent rapid-fire toggles

    while running {
        let now = Date()
        let rawElapsed = -start.timeIntervalSince(now)
        let elapsed = rawElapsed - totalPaused
        let remaining = max(0, Double(totalSeconds) - elapsed)
        let pct = min(1.0, max(0.0, elapsed / Double(totalSeconds)))
        let remSec = Int(remaining.rounded(.up))
        let elaSec = Int(max(0, elapsed))

        if isTTY {
            let color: String
            let statusLine: String
            if isTimerPaused {
                color = rgb(255, 210, 60)
                statusLine = "\(fgBold())⏸  PAUSED\(fgReset())"
            } else {
                color = gradientColor(1.0 - pct)
                let spin = SPINNER[si % SPINNER.count]; si += 1
                statusLine = "\(fgBold())\(spin)  media-pause · \(browser.displayName)\(fgReset())"
            }

            let subtitle = isTimerPaused
                ? "\(rgb(255, 210, 60))[Space] Resume timer & playback\(fgReset())"
                : "\(rgb(140, 140, 140))\(actionLabel) · [Space] Pause timer & playback\(fgReset())"

            let bar = buildBar(progress: pct, width: barW)
            let barLine    = "\(color)\(bar)  \(fgBold())\(Int(pct * 100))%\(fgReset())"
            let remainLine = "\(color)⏳ Remaining: \(fgBold())\(formatHMS(remSec))\(fgReset())"
            let elapsLine  = "\(rgb(140, 140, 140))⏱  Elapsed:  \(formatHMS(elaSec))\(fgReset())"

            let box = drawBox(width: boxW, lines: [statusLine, subtitle, "", barLine, remainLine, elapsLine])
            print("\(cursorHome())\(box)")
        } else {
            if elaSec % 30 == 0 && elaSec > 0 && !isTimerPaused {
                print("[media-pause] \(formatHMS(remSec)) remaining (\(Int(pct * 100))%)")
            }
        }
        fflush(stdout)

        // Check for Space key (pause/resume toggle)
        if stdinEnabled && checkSpaceKey() {
            let t = -start.timeIntervalSinceNow
            if t - lastHotkeyTime >= spaceCooldown {
                lastHotkeyTime = t
                isTimerPaused.toggle()
                if isTimerPaused {
                    _ = pauseMedia()
                    pausedAt = Date()
                } else {
                    _ = resumeMedia()
                    if let p = pausedAt {
                        totalPaused += -p.timeIntervalSinceNow
                        pausedAt = nil
                    }
                }
            }
        }

        if remaining <= 0 { break }

        if !isTimerPaused {
            usleep(TICK_US)
        } else {
            usleep(TICK_US)  // keep polling for Space even when paused
        }
    }

    // --- Cancelled ---
    guard running else {
        print("\n\(clearScreen())\(cursorHome())\(rgb(255, 180, 50))⚠  Cancelled\(fgReset())")
        return
    }

    // --- Completion ---
    print(clearScreen() + cursorHome(), terminator: "")

    if isTTY {
        let icons = ["🎉", "✨", "🚀", "💫"]
        for _ in 0..<10 {
            let icon = icons[Int.random(in: 0..<icons.count)]
            let actionText: String
            switch mode {
            case "mute":      actionText = "\(gradientColor(0.2))🔇 Muting audible tabs...\(fgReset())"
            case "quit":      actionText = "\(gradientColor(0.0))🚫 Shutting down \(browser.displayName)...\(fgReset())"
            case "playpause": actionText = "\(gradientColor(0.2))⏯  Sending play/pause media key...\(fgReset())"
            default:          actionText = "\(gradientColor(0.2))⏸  Pausing media on all tabs...\(fgReset())"
            }
            let box = drawBox(width: boxW, lines: [
                "\(icon)  Time's Up!  \(icon)",
                "",
                actionText,
            ])
            print("\(cursorHome())\(box)")
            fflush(stdout)
            usleep(100_000)
        }
    } else {
        print("media-pause: Time's up! Executing action...")
    }

    // Execute action
    print(clearScreen() + cursorHome(), terminator: "")

    switch mode {
    case "quit":
        var box = drawBox(width: boxW, lines: [
            "🚫  Quit \(browser.displayName)",
            "",
            "\(gradientColor(0.0))Shutting down \(browser.displayName)...\(fgReset())",
        ])
        print(box)
        fflush(stdout)

        let ok = quitBrowser()
        box = drawBox(width: boxW, lines: [
            "🚫  Quit \(browser.displayName)",
            "",
            ok
                ? "\(rgb(100, 255, 100))✓  \(browser.displayName) closed successfully\(fgReset())"
                : "\(rgb(255, 200, 100))⚠  \(browser.displayName) is not running\(fgReset())",
        ])
        print("\(cursorHome())\(box)")

    case "mute":
        showResult(result: muteAudibleTabs(), boxW: boxW, icon: "🔇", label: "Mute Tabs", verb: "Muted")

    case "playpause":
        var box = drawBox(width: boxW, lines: [
            "⏯  Play/Pause",
            "",
            "\(rgb(140, 200, 255))Sending system media key...\(fgReset())",
        ])
        print(box)
        fflush(stdout)
        let ok = sendMediaPlayPause()
        box = drawBox(width: boxW, lines: [
            "⏯  Play/Pause",
            "",
            ok
                ? "\(rgb(100, 255, 100))✓  Media key sent\(fgReset())"
                : "\(rgb(255, 200, 100))⚠  Failed to send media key (may need Accessibility permission)\(fgReset())",
        ])
        print("\(cursorHome())\(box)")

    default:
        showResult(result: pauseMedia(), boxW: boxW, icon: "⏸", label: "Pause Media", verb: "Paused")
    }

    print("")
    fflush(stdout)
}

// MARK: - Result Display

func showResult(result: ActionResult, boxW: Int, icon: String, label: String, verb: String = "Paused") {
    let statusColor: String
    let statusIcon: String
    let message: String

    if result.jsDisabled {
        statusColor = rgb(255, 180, 50)
        statusIcon = "⚠"
        message = """
            \(browser.displayName) JS injection is disabled!

            Enable in \(browser.displayName): View > Developer >
            "Allow JavaScript from Apple Events"
            """
    } else if let err = result.error, !err.isEmpty {
        statusColor = rgb(255, 180, 50)
        statusIcon = "⚠"
        message = "Error: \(err)"
    } else if result.affected > 0 {
        statusColor = rgb(100, 255, 100)
        statusIcon = "✓"
        message = "\(verb) media on \(result.affected) of \(result.total) tab\(result.total == 1 ? "" : "s")"
    } else {
        statusColor = rgb(140, 200, 255)
        statusIcon = "ℹ"
        message = "No media elements found on \(result.total) tab\(result.total == 1 ? "" : "s")"
    }

    let box = drawBox(width: max(boxW, 50), lines: [
        "\(icon)  \(label)",
        "",
        "\(statusColor)\(statusIcon)  \(message)\(fgReset())",
    ])
    print(box)
    fflush(stdout)
}

main()
