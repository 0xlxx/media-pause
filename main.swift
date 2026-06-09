#!/usr/bin/swift

import Foundation
import AppKit
import CoreGraphics

// MARK: - Constants

let VERSION = "3.0.0"

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

// Current browsers (set during argument parsing, defaults to Chrome)
var browsers: [Browser] = []
var nowMode = false
var chromeProfileDir: String? = nil

// MARK: - Version & Help & Profile Listing

func showVersion() {
    print("media-pause \(VERSION)")
    exit(0)
}

/// Enable "Allow JavaScript from Apple Events" in all Chrome profiles.
/// Enable JS from Apple Events in all Chrome profiles (including custom user-data-dir).
/// Detects all running Chrome instances and their user data directories.
func fixChromeJS() {
    // Collect all Chrome user data directories from running processes
    var dataDirs: Set<String> = []
    let defaultBase = NSHomeDirectory() + "/Library/Application Support/Google/Chrome"
    dataDirs.insert(defaultBase)
    
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/ps")
    task.arguments = ["axo", "args"]
    let outPipe = Pipe()
    task.standardOutput = outPipe
    
    // Read asynchronously to prevent pipe deadlock
    var outputData = Data()
    let semaphore = DispatchSemaphore(value: 0)
    outPipe.fileHandleForReading.readabilityHandler = { handle in
        let data = handle.availableData
        if data.isEmpty {
            outPipe.fileHandleForReading.readabilityHandler = nil
            semaphore.signal()
        } else {
            outputData.append(data)
        }
    }
    
    try? task.run()
    task.waitUntilExit()
    // Wait for readability handler to finish
    _ = semaphore.wait(timeout: .now() + 3)
    
    let output = String(data: outputData, encoding: .utf8) ?? ""
    for line in output.components(separatedBy: "\n") {
        if line.contains("/Google Chrome") || line.contains("/Chromium") {
            // Extract --user-data-dir value
            let parts = line.components(separatedBy: "--user-data-dir=")
            if parts.count > 1 {
                let dir = parts[1].components(separatedBy: " ").first ?? ""
                if !dir.isEmpty { dataDirs.insert(dir) }
            }
        }
    }
    
    var count = 0
    for dataDir in dataDirs.sorted() {
        // Get profile directories in this user data dir
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: dataDir) else { continue }
        let profiles = items.filter { $0.hasPrefix("Profile") || $0 == "Default" }.sorted()
        
        for p in profiles {
            let prefPath = dataDir + "/\(p)/Preferences"
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: prefPath)),
                  var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            var browser = json["browser"] as? [String: Any] ?? [:]
            let label = dataDir == defaultBase ? p : "\(dataDir) > \(p)"
            if browser["allow_javascript_apple_events"] as? Bool == true {
                print("  \(label): already enabled ✅")
                continue
            }
            browser["allow_javascript_apple_events"] = true
            json["browser"] = browser
            if let out = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
                try? out.write(to: URL(fileURLWithPath: prefPath))
                print("  \(label): fixed ✅")
                count += 1
            }
        }
    }
    
    // Also try menu click for the frontmost Chrome (live update)
    let viewNames = ["显示", "View", "查看"]
    let devNames  = ["开发者", "Developer"]
    let jsNames   = ["允许 Apple 事件中的 JavaScript", "Allow JavaScript from Apple Events"]
    for vName in viewNames {
        var done = false
        for dName in devNames {
            for jName in jsNames {
                if let ascript = NSAppleScript(source: """
                    tell application "System Events"
                        tell process "Google Chrome"
                            try
                                set devItem to menu item "\(dName)" of menu 1 of menu bar item "\(vName)" of menu bar 1
                                set jsItem to menu item "\(jName)" of menu 1 of devItem
                                set mark to value of attribute "AXMenuItemMarkChar" of jsItem
                                if mark is missing value then click jsItem
                            end try
                        end tell
                    end tell
                """) {
                    var err: NSDictionary?
                    let _ = ascript.executeAndReturnError(&err)
                    if err == nil { done = true; break }
                }
            }
            if done { break }
        }
        if done { break }
    }
    
    print("\(count == 0 ? "All already " : "")fixed")
}

func listProfiles() {
    let base = NSHomeDirectory() + "/Library/Application Support/Google/Chrome"
    guard let items = try? FileManager.default.contentsOfDirectory(atPath: base) else {
        print("No Chrome profiles found")
        exit(0)
    }
    let profiles = items.filter { $0.hasPrefix("Profile") }.sorted()
    if profiles.isEmpty {
        print("No named profiles found (using Default profile)")
        exit(0)
    }
    // Read info_cache from Local State for rich profile data
    let lsPath = base + "/Local State"
    var cache: [String: [String: Any]] = [:]
    if let lsData = try? Data(contentsOf: URL(fileURLWithPath: lsPath)),
       let lsJSON = try? JSONSerialization.jsonObject(with: lsData) as? [String: Any],
       let infoCache = lsJSON["profile"] as? [String: Any],
       let ic = infoCache["info_cache"] as? [String: [String: Any]] {
        cache = ic
    }
    for p in profiles {
        let prefPath = base + "/\(p)/Preferences"
        
        // Person info from info_cache
        var identity = ""
        if let ic = cache[p] {
            if let email = ic["user_name"] as? String, !email.isEmpty {
                identity = email
                if let gaia = ic["gaia_name"] as? String, !gaia.isEmpty {
                    identity = "\(gaia) (\(email))"
                }
            }
        }
        
        // JS from Apple Events setting
        var jsEnabled = false
        if let data = try? Data(contentsOf: URL(fileURLWithPath: prefPath)),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            jsEnabled = (json["browser"] as? [String: Any])?["allow_javascript_apple_events"] as? Bool ?? false
        }
        
        let jsTag = jsEnabled ? "✅ JS enabled" : "❌ JS disabled"
        if identity.isEmpty {
            print("\(p)   \(jsTag)")
        } else {
            print("\(p)   \(identity)")
            print("        \(jsTag)")
        }
    }
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
          -b, --browser <name>  Target browser(s) (default: chrome)
                                Comma-separated: -b chrome,brave
                                Repeatable:      -b chrome -b brave
                                All browsers:    -b all
          -n, --now             Execute immediately (skip countdown)
          --profile <dir>       Chrome profile directory (e.g. "Profile 7")
          --list-profiles       List available Chrome profiles
          --fix-perms           Enable JS from Apple Events in all Chrome profiles (restarts Chrome)
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
          \(name) 45m                  Pause browser media after 45 minutes
          \(name) -p 30m               Send play/pause key after 30 minutes (any app)
          \(name) -r                   Resume previously paused browser media
          \(name) -r 10s               Resume, play for 10 seconds, then pause again
          \(name) -b brave 30m         Pause Brave browser media after 30 minutes
          \(name) -b chrome,brave 30m  Pause Chrome and Brave after 30 minutes
          \(name) -b all 30m           Pause all installed browsers after 30 minutes
          \(name) -b edge -q 1h        Quit Edge after 1 hour
          \(name) -m 1h                Mute audible tabs after 1 hour

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
        case 0x1F000...0x1FFFF:
            w += 2  // Emoticons/Emoji — always wide
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
        let displayLine: String
        let pad: Int
        if lineW > inner {
            displayLine = String(plain.prefix(inner - 1)) + "…"
            pad = 0
        } else {
            displayLine = line
            pad = inner - lineW
        }
        let pl = pad / 2; let pr = pad - pl
        let padded = String(repeating: " ", count: pl) + displayLine + String(repeating: " ", count: pr)
        if i == 1 { out += "├" + String(repeating: "─", count: inner) + "┤\n" }
        out += "│" + padded + "│\n"
    }
    out += "╰" + String(repeating: "─", count: inner) + "╯"
    return out
}

// MARK: - App Nap Prevention

func preventAppNap() -> NSObjectProtocol? {
    ProcessInfo.processInfo.beginActivity(
        options: [.background, .idleSystemSleepDisabled],
        reason: "media-pause countdown timer"
    )
}

// MARK: - Browser JS Capability Check

/// If multiple Chrome instances are running, activate the one with the most
/// on-screen windows (likely the user's main browser, not the automation one).
/// If a profile directory is specified, activate that profile instead.
func activateMainChrome() {
    let chromeProcs = NSWorkspace.shared.runningApplications
        .filter { $0.bundleIdentifier == Browser.byKey("chrome")!.bundleID }
    
    // Activate specified profile if requested
    if let profile = chromeProfileDir {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", "Google Chrome", "--args", "--profile-directory=\(profile)"]
        try? task.run()
        task.waitUntilExit()
        return
    }
    
    if chromeProcs.count <= 1 {
        chromeProcs.first?.activate()
        return
    }
    // Count on-screen windows per Chrome PID
    var counts: [pid_t: Int] = [:]
    if let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] {
        for w in windows {
            let pid = w[kCGWindowOwnerPID as String] as? pid_t ?? 0
            if pid > 0, chromeProcs.contains(where: { $0.processIdentifier == pid }) {
                counts[pid, default: 0] += 1
            }
        }
    }
    let best = chromeProcs.max { a, b in
        (counts[a.processIdentifier] ?? 0) < (counts[b.processIdentifier] ?? 0)
    } ?? chromeProcs.first
    best?.activate()
}

func checkBrowserJSCapability(for browser: Browser) -> String? {
    activateMainChrome()
    let script = """
    with timeout of 10 seconds
        tell application "\(browser.appleScriptName)"
            if (count of windows) = 0 then return "OK"
            set lastErr to ""
            set limit to 0
            repeat with w in windows
                try
                    set wTabs to tabs of w
                    repeat with t in wTabs
                        set limit to limit + 1
                        if limit > 10 then return "OK"
                        try
                            execute t javascript "true"
                            return "OK"
                        on error e
                            set lastErr to e
                        end try
                    end repeat
                end try
            end repeat
            return lastErr
        end tell
    end timeout
    """

    guard let appleScript = NSAppleScript(source: script) else {
        return "Internal error: could not create AppleScript"
    }
    var error: NSDictionary?
    let result = appleScript.executeAndReturnError(&error).stringValue ?? ""

    if result == "OK" { return nil }

    if result.contains("JavaScript") || result.contains("AppleScript") || result.contains("Apple Events") {
        // Auto-fix: enable JS from Apple Events via menu click
        fixChromeJS()
        
        // Retry check after fix
        let retryScript = """
        with timeout of 5 seconds
            tell application "\(browser.appleScriptName)"
                if (count of windows) = 0 then return "OK"
                try
                    execute (tab 1 of window 1) javascript "true"
                    return "OK"
                on error e
                    return e
                end try
            end tell
        end timeout
        """
        if let retryAS = NSAppleScript(source: retryScript) {
            var retryErr: NSDictionary?
            let retryResult = retryAS.executeAndReturnError(&retryErr).stringValue ?? ""
            if retryResult == "OK" {
                return nil  // fixed successfully
            }
        }
        
        // Still failing — likely automation Chrome with --enable-automation
        // Quit automation Chrome instances and retry one more time
        if let chromeApps = try? FileManager.default.contentsOfDirectory(atPath: "/Applications"),
           chromeApps.contains("Google Chrome.app") {
            _ = ""
        }
        // Scan all processes for automation Chrome via ps
        let pstask = Process()
        pstask.executableURL = URL(fileURLWithPath: "/bin/bash")
        pstask.arguments = ["-c", "ps axo pid,args | grep 'Google Chrome.*enable-automation' | grep -v grep"]
        let pspipe = Pipe()
        pstask.standardOutput = pspipe
        try? pstask.run()
        pstask.waitUntilExit()
        let psdata = pspipe.fileHandleForReading.readDataToEndOfFile()
        let psstr = String(data: psdata, encoding: .utf8) ?? ""
        for line in psstr.components(separatedBy: "\n") {
            let pidStr = line.trimmingCharacters(in: .whitespaces).components(separatedBy: " ").first ?? ""
            if let pid = pid_t(pidStr), pid > 0 {
                NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid })?.terminate()
            }
        }
        if !psstr.isEmpty { Thread.sleep(forTimeInterval: 1) }
        
        if let retryAS2 = NSAppleScript(source: retryScript) {
            var retryErr2: NSDictionary?
            let retryResult2 = retryAS2.executeAndReturnError(&retryErr2).stringValue ?? ""
            if retryResult2 == "OK" {
                return nil  // fixed after quitting automation Chrome
            }
        }
        
        return """
            \(browser.displayName): "Allow JavaScript from Apple Events" is disabled.
            media-pause attempted to enable it automatically but failed.
            Please enable it manually:
              View > Developer > Allow JavaScript from Apple Events
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

// MARK: - Multi-Browser Result

struct BrowserResult {
    let browser: Browser
    let result: ActionResult
}

// MARK: - Browser Actions (via AppleScript + JS injection)

func makeAppleScript(js: String, for browser: Browser) -> String {
    let escapedJS = js
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    return """
    with timeout of 120 seconds
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
                            with timeout of 5 seconds
                                execute t javascript "\(escapedJS)"
                            end timeout
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
    end timeout
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

func pauseMedia(for browser: Browser) -> ActionResult {
    // Use system media key (works with ALL apps, no permissions needed)
    let ok = pauseAllMedia()
    return ActionResult(affected: ok ? 1 : 0, total: 1, tabs: [],
                        error: ok ? nil : "System media pause failed", jsDisabled: false)
}

func resumeMedia(for browser: Browser) -> ActionResult {
    let ok = resumeAllMedia()
    return ActionResult(affected: ok ? 1 : 0, total: 1, tabs: [],
                        error: ok ? nil : "System media resume failed", jsDisabled: false)
}

func muteAudibleTabs(for browser: Browser) -> ActionResult {
    activateMainChrome()
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

func quitBrowser(for browser: Browser) -> Bool {
    NSWorkspace.shared.runningApplications
        .first { $0.bundleIdentifier == browser.bundleID }?
        .terminate() ?? false
}

// MARK: - System Media Key (MediaRemote private framework — same API as Control Center)

typealias MRMediaRemoteSendCommandFunc = @convention(c) (UInt32, AnyObject?) -> Bool

let MRCommandPause: UInt32 = 1  // kMRPause
let MRCommandPlay: UInt32 = 0   // kMRPlay
let MRCommandToggle: UInt32 = 2 // kMRTogglePlayPause

var mrHandle: UnsafeMutableRawPointer? = nil
var mrSend: MRMediaRemoteSendCommandFunc? = nil

func ensureMediaRemote() {
    guard mrSend == nil else { return }
    if let handle = dlopen(
        "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote",
        RTLD_NOW
    ) {
        mrHandle = handle
        if let sym = dlsym(handle, "MRMediaRemoteSendCommand") {
            mrSend = unsafeBitCast(sym, to: MRMediaRemoteSendCommandFunc.self)
        }
    }
}

func sendMediaCommand(_ command: UInt32) -> Bool {
    ensureMediaRemote()
    return mrSend?(command, nil) ?? false
}

func pauseAllMedia() -> Bool {
    sendMediaCommand(MRCommandPause)
}

func resumeAllMedia() -> Bool {
    sendMediaCommand(MRCommandPlay)
}

func toggleMediaPlayPause() -> Bool {
    sendMediaCommand(MRCommandToggle)
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
        case "--list-profiles": listProfiles()
        case "--fix-perms":
            fixChromeJS()
            exit(0)
        case "-n", "--now":    nowMode = true
        case "-r", "--resume":  mode = "resume"
        case "-p", "--playpause": mode = "playpause"
        case "-m", "--mute":    mode = "mute"
        case "-q", "--quit":    mode = "quit"
        case "--profile":
            i = args.index(after: i)
            guard i < args.endIndex else {
                fputs("Error: --profile requires a profile name (e.g. 'Profile 7')\n", stderr)
                exit(1)
            }
            chromeProfileDir = args[i]
        case "-b", "--browser":
            i = args.index(after: i)
            if i < args.endIndex {
                let raw = args[i]
                for key in raw.lowercased().split(separator: ",").map({ String($0).trimmingCharacters(in: .whitespaces) }) {
                    if key == "all" {
                        browsers.append(contentsOf: Browser.all)
                    } else if let b = Browser.byKey(key) {
                        browsers.append(b)
                    } else {
                        fputs("Error: Unknown browser '\(key)'\n  Valid: all, \(Browser.all.map(\.key).joined(separator: ", "))\n", stderr)
                        exit(1)
                    }
                }
            } else {
                fputs("Error: -b requires a browser name\n", stderr)
                exit(1)
            }
        default:
            durStr = arg
        }
        i = args.index(after: i)
    }

    // Deduplicate and default to Chrome
    var seen: Set<String> = []
    browsers = browsers.filter { seen.insert($0.key).inserted }
    if browsers.isEmpty {
        browsers = [Browser.byKey("chrome")!]
    }

    // --- Immediate execution (--now) ---
    if nowMode {
        // Pause/resume use system media key — no JS setup needed
        // Mute mode below handles its own pre-flight

        // Handle resume separately (has its own display logic)
        if mode == "resume" {
            let label = browsers.count == 1 ? browsers[0].displayName : "\(browsers.count) browsers"
            print(hideCursor(), terminator: "")
            print(clearScreen() + cursorHome(), terminator: "")
            let box = drawBox(width: 62, lines: [
                "\(fgBold())▶  Resuming media on \(label) tabs...\(fgReset())",
                "",
                "\(rgb(140, 200, 255))Restoring previously-paused media...\(fgReset())",
            ])
            print(box)
            fflush(stdout)
            var allResults: [BrowserResult] = []
            for b in browsers {
                allResults.append(BrowserResult(browser: b, result: resumeMedia(for: b)))
            }
            showResults(allResults, boxW: 62, icon: "▶", label: "Resume Media", verb: "Resumed")
            print("")
            print(showCursor(), terminator: "")
            fflush(stdout)
            let ok = allResults.allSatisfy { $0.result.error == nil }
            exit(ok ? 0 : 1)
        }

        // Execute action immediately (pause, mute, quit, playpause)
        print(hideCursor(), terminator: "")
        let boxW: Int
        if isTTY {
            var ws = winsize()
            if ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &ws) == 0 && ws.ws_col > 0 {
                boxW = max(20, min(Int(ws.ws_col), 64))
            } else {
                boxW = 64
            }
        } else {
            boxW = 64
        }
        let ok = executeModeAction(mode: mode, boxW: boxW)
        print("")
        print(showCursor(), terminator: "")
        fflush(stdout)
        exit(ok ? 0 : 1)
    }

    // --- Resume mode ---
    if mode == "resume" {
        if let dur = durStr {
            // Resume immediately, then count down to pause
            let totalSeconds = parseDuration(dur)
            var allResults: [BrowserResult] = []
            for b in browsers {
                allResults.append(BrowserResult(browser: b, result: resumeMedia(for: b)))
            }
            let hasError = allResults.contains { $0.result.jsDisabled || $0.result.error != nil }
            if hasError {
                print(hideCursor(), terminator: "")
                print(clearScreen() + cursorHome(), terminator: "")
                showResults(allResults, boxW: 62, icon: "▶", label: "Resume Media", verb: "Resumed")
                print(showCursor(), terminator: "")
                fflush(stdout)
                exit(1)
            }
            // Run the countdown, then pause
            runTimer(totalSeconds: totalSeconds, mode: "pause")
        } else {
            // Just resume, no timer
            let label = browsers.count == 1 ? browsers[0].displayName : "\(browsers.count) browsers"
            print(hideCursor(), terminator: "")
            print(clearScreen() + cursorHome(), terminator: "")
            let box = drawBox(width: 62, lines: [
                "\(fgBold())▶  Resuming media on \(label) tabs...\(fgReset())",
                "",
                "\(rgb(140, 200, 255))Restoring previously-paused media...\(fgReset())",
            ])
            print(box)
            fflush(stdout)
            var allResults: [BrowserResult] = []
            for b in browsers {
                allResults.append(BrowserResult(browser: b, result: resumeMedia(for: b)))
            }
            showResults(allResults, boxW: 62, icon: "▶", label: "Resume Media", verb: "Resumed")
            print("")
            print(showCursor(), terminator: "")
            fflush(stdout)
            let ok = allResults.allSatisfy { $0.result.error == nil }
            exit(ok ? 0 : 1)
        }
        return
    }

    // --- All other modes require a duration ---
    let totalSeconds = parseDuration(durStr ?? "1h")

    // Pause/resume use system media key — no JS setup needed

    runTimer(totalSeconds: totalSeconds, mode: mode)
}

// MARK: - Mode Action Execution (shared by timer completion and --now)

func executeModeAction(mode: String, boxW: Int) -> Bool {
    switch mode {
    case "quit":
        let quitLabel = browsers.count == 1 ? browsers[0].displayName : "\(browsers.count) browsers"
        let quitBox = drawBox(width: boxW, lines: [
            "🚫  Quit \(quitLabel)",
            "",
            "\(gradientColor(0.0))Shutting down \(quitLabel)...\(fgReset())",
        ])
        print(quitBox)
        fflush(stdout)

        var quitResults: [BrowserResult] = []
        for b in browsers {
            let ok = quitBrowser(for: b)
            let result = ActionResult(affected: ok ? 1 : 0, total: 1, tabs: [], error: ok ? nil : "\(b.displayName) is not running", jsDisabled: false)
            quitResults.append(BrowserResult(browser: b, result: result))
        }
        showResults(quitResults, boxW: boxW, icon: "🚫", label: "Quit Browsers", verb: "Quit")
        return quitResults.allSatisfy { $0.result.error == nil }

    case "mute":
        var muteResults: [BrowserResult] = []
        for b in browsers {
            muteResults.append(BrowserResult(browser: b, result: muteAudibleTabs(for: b)))
        }
        showResults(muteResults, boxW: boxW, icon: "🔇", label: "Mute Tabs", verb: "Muted")
        return muteResults.allSatisfy { $0.result.error == nil }

    case "playpause":
        var box = drawBox(width: boxW, lines: [
            "⏯  Play/Pause",
            "",
            "\(rgb(140, 200, 255))Sending system media key...\(fgReset())",
        ])
        print(box)
        fflush(stdout)
        let ok = toggleMediaPlayPause()
        box = drawBox(width: boxW, lines: [
            "⏯  Play/Pause",
            "",
            ok
                ? "\(rgb(100, 255, 100))✓  Media key sent\(fgReset())"
                : "\(rgb(255, 200, 100))⚠  Failed to send media key (may need Accessibility permission)\(fgReset())",
        ])
        print("\(cursorHome())\(box)")
        return ok

    default:
        var pauseResults: [BrowserResult] = []
        for b in browsers {
            pauseResults.append(BrowserResult(browser: b, result: pauseMedia(for: b)))
        }
        showResults(pauseResults, boxW: boxW, icon: "⏸", label: "Pause Media", verb: "Paused")
        return pauseResults.allSatisfy { $0.result.error == nil }
    }
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
    let barW = max(10, termW - 16)

    // Dynamic tick: match framerate to progress bar's visible granularity
    let steps = Double(barW * 8)
    let tickInterval = max(0.05, min(0.5, Double(totalSeconds) / (steps * 2.0)))
    let tickUS = UInt32(tickInterval * 1_000_000)

    print(hideCursor(), terminator: "")
    print(clearScreen() + cursorHome(), terminator: "")

    let start = Date()
    var si = 0

    let browserLabel: String
    if browsers.count == 1 {
        browserLabel = browsers[0].displayName
    } else {
        browserLabel = "\(browsers.count) browsers"
    }
    let actionLabel: String
    switch mode {
    case "mute":      actionLabel = "Muting audible tabs when done"
    case "quit":      actionLabel = "Quitting \(browserLabel) when done"
    case "playpause": actionLabel = "Sending play/pause media key when done"
    default:          actionLabel = "Pausing media on all tabs when done"
    }

    if !isTTY {
        print("media-pause [\(browserLabel)]: \(actionLabel.lowercased()) in \(formatHMS(totalSeconds))")
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
                statusLine = "\(fgBold())\(spin)  media-pause · \(browserLabel)\(fgReset())"
            }

            let subtitle = isTimerPaused
                ? "\(rgb(255, 210, 60))[Space] Resume timer & playback\(fgReset())"
                : "\(rgb(140, 140, 140))\(actionLabel) · [Space] Pause timer & playback\(fgReset())"

            let bar = buildBar(progress: pct, width: barW)
            let barLine    = "\(color)\(bar)  \(fgBold())\(String(format: "%3d%%", Int(pct * 100)))\(fgReset())"
            let remainLine = "\(color)⏳ Remaining: \(fgBold())\(formatHMS(remSec))\(fgReset())"
            let elapsLine  = "\(rgb(140, 140, 140))⏱  Elapsed:  \(formatHMS(elaSec))\(fgReset())"

            let clear = String(repeating: " ", count: termW)
            let lines = ["  \(statusLine)", "  \(subtitle)", "", "  \(barLine)", "  \(remainLine)", "  \(elapsLine)"]
            let frame = lines.map { String(($0 + clear).prefix(termW)) }.joined(separator: "\n")
            print("\(cursorHome())\(frame)")
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
                    for b in browsers { _ = pauseMedia(for: b) }
                    pausedAt = Date()
                } else {
                    for b in browsers { _ = resumeMedia(for: b) }
                    if let p = pausedAt {
                        totalPaused += -p.timeIntervalSinceNow
                        pausedAt = nil
                    }
                }
            }
        }

        if remaining <= 0 { break }

        if !isTimerPaused {
            usleep(tickUS)
        } else {
            usleep(tickUS)  // keep polling for Space even when paused
        }
    }

    // --- Cancelled ---
    guard running else {
        print("\n\(clearScreen())\(cursorHome())\(rgb(255, 180, 50))⚠  Cancelled\(fgReset())")
        return
    }

    // --- Completion ---
    print(clearScreen() + cursorHome(), terminator: "")

    let boxW = max(20, min(termW, 64))
    executeModeAction(mode: mode, boxW: boxW)

    print("")
    print(showCursor(), terminator: "")
    fflush(stdout)
}

// MARK: - Result Display

func showResults(_ results: [BrowserResult], boxW: Int, icon: String, label: String, verb: String = "Paused") {
    var resultLines: [String] = []

    for br in results {
        let r = br.result
        let b = br.browser
        let line: String

        if r.jsDisabled {
            line = "\(rgb(255, 180, 50))⚠  \(b.displayName): JS injection disabled\(fgReset())"
        } else if let err = r.error, !err.isEmpty {
            line = "\(rgb(255, 180, 50))⚠  \(b.displayName): \(err)\(fgReset())"
        } else if r.affected > 0 {
            line = "\(rgb(100, 255, 100))✓  \(b.displayName): \(verb) media on \(r.affected) of \(r.total) tab\(r.total == 1 ? "" : "s")\(fgReset())"
        } else {
            line = "\(rgb(140, 200, 255))ℹ  \(b.displayName): No media found on \(r.total) tab\(r.total == 1 ? "" : "s")\(fgReset())"
        }
        resultLines.append(line)
    }

    let totalAffected = results.reduce(0) { $0 + $1.result.affected }
    let totalTabs = results.reduce(0) { $0 + $1.result.total }
    let allDisabled = results.allSatisfy { $0.result.jsDisabled }
    let summary: String
    if allDisabled {
        summary = "\(rgb(255, 180, 50))Tip: Close automation/testing Chrome, or enable Allow JavaScript from Apple Events in all Chrome instances\(fgReset())"
    } else if results.contains(where: { $0.result.jsDisabled || $0.result.error != nil }) {
        summary = ""
    } else {
        summary = "\(rgb(140, 140, 140))Total: \(verb.lowercased()) \(totalAffected) of \(totalTabs) tab\(totalTabs == 1 ? "" : "s") across \(results.count) browser\(results.count == 1 ? "" : "s")\(fgReset())"
    }

    var lines: [String] = ["\(icon)  \(label)", ""]
    lines.append(contentsOf: resultLines)
    if !summary.isEmpty {
        lines.append("")
        lines.append(summary)
    }

    let box = drawBox(width: max(boxW, 50), lines: lines)
    print(box)
    fflush(stdout)
}

main()
