import AppKit
import CoreGraphics
import Darwin
import Foundation
import MediaPauseCore

// MARK: - Terminal helpers

private var runningFlag = true
private var originalTermios = termios()

private func setupSignals() {
    signal(SIGINT)  { _ in runningFlag = false }
    signal(SIGTERM) { _ in runningFlag = false }
    signal(SIGQUIT) { _ in runningFlag = false }
    signal(SIGWINCH, SIG_IGN)
}

private func isTTY() -> Bool {
    isatty(STDOUT_FILENO) == 1
}

private func enableRawStdin() -> Bool {
    guard isatty(STDIN_FILENO) == 1 else { return false }
    tcgetattr(STDIN_FILENO, &originalTermios)
    var raw = originalTermios
    raw.c_lflag &= ~UInt(ICANON | ECHO)
    raw.c_cc.0 = 0 // VMIN
    raw.c_cc.1 = 0 // VTIME
    tcsetattr(STDIN_FILENO, TCSANOW, &raw)
    _ = fcntl(STDIN_FILENO, F_SETFL, O_NONBLOCK)
    return true
}

private func restoreStdin() {
    tcsetattr(STDIN_FILENO, TCSANOW, &originalTermios)
}

private func readKeyByte() -> UInt8? {
    var buf = [UInt8](repeating: 0, count: 1)
    let n = read(STDIN_FILENO, &buf, 1)
    return n == 1 ? buf[0] : nil
}

private func hideCursor() -> String { isTTY() ? "\u{001B}[?25l" : "" }
private func showCursor() -> String { isTTY() ? "\u{001B}[?25h" : "" }
private func clearScreen() -> String { isTTY() ? "\u{001B}[2J" : "" }
private func cursorHome() -> String { isTTY() ? "\u{001B}[H" : "" }

private func progressBar(progress: Double, width: Int) -> String {
    let w = max(1, width)
    let filled = Int(progress * Double(w))
    let empty = max(0, w - filled)
    return String(repeating: "█", count: filled) + String(repeating: "░", count: empty)
}

private func terminalWidth() -> Int {
    var ws = winsize()
    guard ioctl(STDOUT_FILENO, UInt(TIOCGWINSZ), &ws) == 0, ws.ws_col > 0 else { return 80 }
    return Int(ws.ws_col)
}

// MARK: - Browser / process plumbing

private func runningInstances(of browser: Browser) -> [NSRunningApplication] {
    NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == browser.bundleID }
}

/// True for testing/automation instances (custom profile, debug pipe, ...).
private func isAutomationInstance(_ app: NSRunningApplication) -> Bool {
    let runner = SystemProcessRunner()
    let (args, _) = runner.run("/bin/ps", ["-ww", "-p", "\(app.processIdentifier)", "-o", "args="], timeout: 2)
    return AutomationArgs.isAutomation(args)
}

/// Quits automation/testing instances of a browser. With multiple Chrome
/// instances running, AppleScript always routes to the automation instance
/// (which has no windows), silently breaking JS injection — so the JS channel
/// quits them first, mirroring the pre-refactor behavior.
private func quitAutomationInstances(of browser: Browser) {
    var terminated = false
    for app in runningInstances(of: browser) where isAutomationInstance(app) {
        if app.terminate() { terminated = true }
    }
    if terminated { Thread.sleep(forTimeInterval: 0.4) }
}

/// Picks the instance most likely to be the user's real browser:
/// non-automation instances first, then the one with the most on-screen
/// windows (mirrors the pre-refactor behavior that was lost in the rewrite).
private func primaryInstance(of browser: Browser) -> NSRunningApplication? {
    let apps = runningInstances(of: browser)
    guard !apps.isEmpty else { return nil }

    let real = apps.filter { !isAutomationInstance($0) }
    let candidates = real.isEmpty ? apps : real

    var windowCounts: [pid_t: Int] = [:]
    if let windows = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] {
        for window in windows {
            let pid = window[kCGWindowOwnerPID as String] as? pid_t ?? 0
            if pid > 0 { windowCounts[pid, default: 0] += 1 }
        }
    }
    return candidates.max { a, b in
        (windowCounts[a.processIdentifier] ?? 0) < (windowCounts[b.processIdentifier] ?? 0)
    } ?? candidates.first
}

private func activateBrowser(_ browser: Browser) {
    primaryInstance(of: browser)?.activate(options: [.activateAllWindows])
}

// MARK: - Channel factory

private func makeEngine(browsers: [Browser], runner: ProcessRunning) -> (engine: MediaEngine, cdpPort: Int?) {
    var channels: [MediaChannel] = []

    var cdpPort: Int? = nil
    if let port = CDP.firstOpenPort(ports: CDP.defaultPorts, probe: { cdpPortOpen($0) }) {
        cdpPort = port
        channels.append(CDPChannel(port: port, transport: URLSessionCDPTransport()))
    }

    for browser in browsers {
        channels.append(AppleScriptChannel(browser: browser, runner: runner, activate: {
            quitAutomationInstances(of: browser)
            activateBrowser(browser)
        }))
        channels.append(MediaKeyChannel(browser: browser, instances: { runningInstances(of: browser) }, hasNowPlaying: { MediaRemote.hasNowPlayingSession() }))
    }

    let fallback = SystemMediaKeyChannel(
        hasNowPlaying: { MediaRemote.hasNowPlayingSession() },
        send: { MediaRemote.sendCommand(MediaRemote.togglePlayPause) }
    )
    return (MediaEngine(channels: channels, fallback: fallback), cdpPort)
}

private func cdpPortOpen(_ port: Int) -> Bool {
    guard let url = URL(string: "http://127.0.0.1:\(port)/json/version") else { return false }
    var request = URLRequest(url: url)
    request.timeoutInterval = 0.4
    let semaphore = DispatchSemaphore(value: 0)
    var open = false
    URLSession.shared.dataTask(with: request) { _, response, _ in
        if let http = response as? HTTPURLResponse, http.statusCode == 200 { open = true }
        semaphore.signal()
    }.resume()
    _ = semaphore.wait(timeout: .now() + 1)
    return open
}

// MARK: - CDP transport (URLSession)

final class URLSessionCDPTransport: CDPTransport {
    func fetchTargets(port: Int) -> [CDPTarget] {
        guard let url = URL(string: "http://127.0.0.1:\(port)/json") else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.0
        let semaphore = DispatchSemaphore(value: 0)
        var targets: [CDPTarget] = []
        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data { targets = CDP.parseTargets(data) }
            semaphore.signal()
        }.resume()
        _ = semaphore.wait(timeout: .now() + 2)
        return targets
    }

    func evaluate(webSocketURL: String, expression: String, timeout: TimeInterval) -> String? {
        guard let url = URL(string: webSocketURL) else { return nil }
        let semaphore = DispatchSemaphore(value: 0)
        var result: String?
        let task = URLSession.shared.webSocketTask(with: url)
        task.resume()
        let payload = CDP.evaluateRequest(id: 1, expression: expression)
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            task.send(.data(data)) { _ in }
        }
        task.receive { [weak task] reply in
            defer { semaphore.signal() }
            switch reply {
            case .success(let message):
                if case .data(let data) = message,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let value = CDP.parseEvaluateValue(json) {
                    result = value
                }
                task?.cancel()
            case .failure:
                task?.cancel()
            }
        }
        _ = semaphore.wait(timeout: .now() + timeout)
        task.cancel()
        return result
    }
}

// MARK: - Action execution

private func resolveBrowsers(_ tokens: [String]) -> Result<[Browser], ArgumentError> {
    if tokens.isEmpty { return .success([Browser.byKey("chrome")!]) }
    var result: [Browser] = []
    var seen: Set<String> = []
    for token in tokens {
        guard let resolved = Browser.resolve(token) else {
            return .failure(ArgumentError("Unknown browser '\(token)'\n  Valid: all, \(Browser.all.map(\.key).joined(separator: ", "))"))
        }
        for b in resolved where seen.insert(b.key).inserted {
            result.append(b)
        }
    }
    return .success(result)
}

private func renderResults(_ results: [ChannelResult], title: String, boxWidth: Int) -> Bool {
    let ok = MediaEngine.anySuccess(results)
    var lines = [title, ""]
    lines.append(contentsOf: results.map { "  \(Report.line(for: $0))" })
    lines.append("")
    lines.append(ok ? "  ✓ Channel\(results.filter(\.ok).count == 1 ? "" : "s") reported success" : "  ✗ No channel succeeded")
    let longest = lines.map(\.count).max() ?? 40
    let width = isTTY() ? max(40, min(boxWidth, longest + 4)) : max(40, longest + 4)
    print(box(lines, width: width))
    return ok
}

private func box(_ lines: [String], width: Int) -> String {
    let inner = max(4, width - 2)
    var out = "╭" + String(repeating: "─", count: inner) + "╮\n"
    for (i, line) in lines.enumerated() {
        let plain = line.replacingOccurrences(of: "\u{001B}\\[[0-9;]*m", with: "", options: .regularExpression)
        let shown = plain.count > inner ? String(plain.prefix(inner - 1)) + "…" : plain
        let pad = max(0, inner - shown.count)
        let left = pad / 2
        let right = pad - left
        if i == 1 { out += "├" + String(repeating: "─", count: inner) + "┤\n" }
        out += "│" + String(repeating: " ", count: left) + shown + String(repeating: " ", count: right) + "│\n"
    }
    out += "╰" + String(repeating: "─", count: inner) + "╯"
    return out
}

/// Executes the final action for a mode; returns success.
private func executeModeAction(mode: Mode, browsers: [Browser], runner: ProcessRunning, store: TimerStateStore) -> Bool {
    let boxWidth = isTTY() ? max(20, min(terminalWidth(), 64)) : 64

    switch mode {
    case .pause:
        let engine = makeEngine(browsers: browsers, runner: runner).engine
        let results = engine.run(resume: false)
        let ok = renderResults(results, title: Report.title(for: .pause), boxWidth: boxWidth)
        store.writeLastResult(Report.summary(of: results))
        return ok

    case .resume:
        let engine = makeEngine(browsers: browsers, runner: runner).engine
        let results = engine.run(resume: true)
        let ok = renderResults(results, title: Report.title(for: .resume), boxWidth: boxWidth)
        store.writeLastResult(Report.summary(of: results))
        return ok

    case .mute:
        let results = MediaEngine(channels: browsers.map { MuteChannel(browser: $0, runner: runner) }).run(resume: false)
        let ok = renderResults(results, title: Report.title(for: .mute), boxWidth: boxWidth)
        store.writeLastResult(Report.summary(of: results))
        return ok

    case .quit:
        var results: [ChannelResult] = []
        for browser in browsers {
            let terminated = runningInstances(of: browser).first?.terminate() ?? false
            results.append(ChannelResult(
                channel: "quit", target: browser.displayName, ok: terminated,
                affected: terminated ? 1 : 0,
                message: terminated ? "quit \(browser.displayName)" : "\(browser.displayName) is not running"
            ))
        }
        let ok = renderResults(results, title: Report.title(for: .quit), boxWidth: boxWidth)
        store.writeLastResult(Report.summary(of: results))
        return ok

    case .playpause:
        var sent = false
        for browser in browsers {
            for app in runningInstances(of: browser) {
                if MediaKeyChannel.postMediaKey(to: app) { sent = true }
            }
        }
        if !sent { sent = MediaRemote.sendCommand(MediaRemote.togglePlayPause) }
        let results = [ChannelResult(
            channel: "key", target: "System", ok: sent, affected: 0,
            message: sent ? "media key sent" : "failed to send media key"
        )]
        let ok = renderResults(results, title: Report.title(for: .playpause), boxWidth: boxWidth)
        store.writeLastResult(Report.summary(of: results))
        return ok
    }
}

/// Posts a completion notification (with sound) via AppleScript's
/// `display notification`. Best-effort: failures are ignored.
private func postCompletionNotification(mode: Mode, label: String, runner: ProcessRunning) {
    let script = CompletionNotification.script(
        title: CompletionNotification.title(for: mode),
        body: CompletionNotification.body(for: mode, label: label)
    )
    _ = runner.run("/usr/bin/osascript", ["-e", script], timeout: 5)
}

// MARK: - Countdown

private func runCountdown(totalSeconds: Int, mode: Mode, browsers: [Browser], runner: ProcessRunning, store: TimerStateStore, notify: Bool) -> Int32 {
    setupSignals()
    let activity = ProcessInfo.processInfo.beginActivity(
        options: [.background, .idleSystemSleepDisabled],
        reason: "media-pause countdown timer"
    )
    defer { ProcessInfo.processInfo.endActivity(activity) }

    let label = browsers.count == 1 ? browsers[0].displayName : "\(browsers.count) browsers"
    let actionLabel: String
    switch mode {
    case .mute:      actionLabel = "Muting audible tabs when done"
    case .quit:      actionLabel = "Quitting \(label) when done"
    case .playpause: actionLabel = "Sending play/pause key when done"
    case .resume:    actionLabel = "Resuming media when done"
    default:         actionLabel = "Pausing media when done"
    }

    let startNow = Date().timeIntervalSince1970
    store.start(pid: getpid(), status: TimerStatus(
        startTs: startNow, totalSeconds: totalSeconds, mode: mode.rawValue, label: label, instanceID: store.instanceID
    ))

    let timer = CountdownTimer(total: TimeInterval(totalSeconds), clock: SystemClock())
    timer.start()

    let rawStdin = enableRawStdin()
    defer {
        if rawStdin { restoreStdin() }
        store.clear()
    }

    let tty = isTTY()
    let termW = tty ? terminalWidth() : 80
    let barWidth = max(10, termW - 16)

    var lastHotkeyAt: TimeInterval = 0
    var lastNonTTYPrint = 0

    if tty {
        print(hideCursor() + clearScreen() + cursorHome(), terminator: "")
    } else {
        print("media-pause [\(label)]: \(actionLabel.lowercased()) in \(Duration.formatHMS(totalSeconds))")
    }
    fflush(stdout)

    while runningFlag && !timer.isCancelled {
        let snap = timer.snapshot()
        if snap.finished { break }

        if tty {
            let pct = Int(snap.progress * 100)
            let status = snap.isPaused
                ? "⏸  PAUSED"
                : "⏳  \(actionLabel) · \(label)"
            let bar = progressBar(progress: snap.progress, width: barWidth)
            let lines = [
                "  \(status)",
                "  \(bar) \(String(format: "%3d", pct))%",
                "  ⏱  Elapsed \(Duration.formatHMS(Int(snap.elapsed)))   Remaining \(Duration.formatHMS(Int(snap.remaining)))",
                "  [Space] pause/resume timer & media · [Ctrl+C] cancel",
            ]
            let clear = String(repeating: " ", count: termW)
            let frame = lines.map { String(($0 + clear).prefix(termW)) }.joined(separator: "\n")
            print(cursorHome() + frame)
        } else {
            let elapsedSec = Int(snap.elapsed)
            if elapsedSec >= lastNonTTYPrint + 30 {
                lastNonTTYPrint = elapsedSec
                print("[media-pause] \(Duration.formatHMS(Int(snap.remaining))) remaining (\(Int(snap.progress * 100))%)")
            }
        }
        fflush(stdout)

        if rawStdin, let byte = readKeyByte(), byte == 0x20 {
            let now = Date().timeIntervalSince1970
            if now - lastHotkeyAt >= 0.3 {
                lastHotkeyAt = now
                let nowPaused = timer.togglePause()
                let engine = makeEngine(browsers: browsers, runner: runner).engine
                DispatchQueue.global().async {
                    _ = engine.run(resume: !nowPaused)
                }
            }
        }

        usleep(50_000)
    }

    if !runningFlag || timer.isCancelled {
        if tty { print("\n" + clearScreen() + cursorHome() + "⚠  Cancelled") } else { print("Cancelled") }
        return 130
    }

    if tty { print(clearScreen() + cursorHome(), terminator: ""); fflush(stdout) }
    let ok = executeModeAction(mode: mode, browsers: browsers, runner: runner, store: store)
    if notify && ok {
        postCompletionNotification(mode: mode, label: label, runner: runner)
    }
    print("")
    print(showCursor(), terminator: "")
    fflush(stdout)
    return ok ? 0 : 1
}

// MARK: - Setup

private func clickAllowJSMenu() -> Bool {
    let viewNames = ["显示", "View", "查看"]
    let devNames = ["开发者", "Developer"]
    let jsNames = ["允许 Apple 事件中的 JavaScript", "Allow JavaScript from Apple Events"]
    for view in viewNames {
        for dev in devNames {
            for js in jsNames {
                let script = """
                tell application "System Events"
                    tell process "Google Chrome"
                        try
                            set devItem to menu item "\(dev)" of menu 1 of menu bar item "\(view)" of menu bar 1
                            set jsItem to menu item "\(js)" of menu 1 of devItem
                            set mark to value of attribute "AXMenuItemMarkChar" of jsItem
                            if mark is missing value then click jsItem
                            return true
                        on error
                            return false
                        end try
                    end tell
                end tell
                """
                guard let appleScript = NSAppleScript(source: script) else { continue }
                var error: NSDictionary?
                let result = appleScript.executeAndReturnError(&error)
                if error == nil, result.stringValue == "true" { return true }
            }
        }
    }
    return false
}

private func runSetup() -> Int32 {
    let runner = SystemProcessRunner()
    var dirs: Set<String> = [ChromeDiscovery.defaultUserDataDir()]
    let (processList, _) = runner.run("/bin/ps", ["axo", "args"], timeout: 2)
    dirs.formUnion(ChromeDiscovery.customUserDataDirs(processList: processList))

    var totalFixed = 0
    for dir in dirs.sorted() {
        let (fixed, _) = PreferencesEditor.enableJavaScriptFromAppleEvents(userDataDir: dir)
        totalFixed += fixed
        print("  \(dir): fixed \(fixed) profile(s)")
    }
    if clickAllowJSMenu() {
        print("  Live update via menu: done")
    }
    print(totalFixed == 0 ? "All already fixed" : "Fixed \(totalFixed) profile(s)")
    return 0
}

// MARK: - Status / Stop

private func runStatus(paths: TimerStatePaths) -> Int32 {
    let store = TimerStateStore(paths: paths)
    guard let pid = store.readPid(),
          let status = store.readStatus(),
          pid.instanceID == status.instanceID,
          kill(pid.pid, 0) == 0 else {
        print("No timer running")
        return 0
    }
    let now = Date().timeIntervalSince1970
    let elapsed = max(0, now - status.startTs)
    let remaining = max(0, Double(status.totalSeconds) - elapsed)
    print("Timer running · \(status.mode) · \(status.label)")
    print("Remaining: \(Duration.formatHMS(Int(remaining)))")
    print("Elapsed:   \(Duration.formatHMS(Int(elapsed)))")
    print("Total:     \(Duration.formatHMS(status.totalSeconds))")
    return 0
}

private func runStop(paths: TimerStatePaths) -> Int32 {
    let store = TimerStateStore(paths: paths)
    guard let pid = store.readPid() else {
        print("No timer running")
        return 0
    }
    kill(pid.pid, SIGTERM)
    for _ in 0..<20 where kill(pid.pid, 0) == 0 {
        usleep(50_000)
    }
    if kill(pid.pid, 0) == 0 {
        kill(pid.pid, SIGKILL)
    }
    store.clear()
    print("Timer stopped")
    return 0
}

// MARK: - App

enum MediaPauseApp {
    static func run(args: [String]) -> Int32 {
        let paths = TimerStatePaths()
        switch Arguments.parse(args) {
        case .failure(let error):
            fputs("Error: \(error.message)\n", stderr)
            return 1
        case .success(.help):
            print(HelpText.text)
            return 0
        case .success(.version):
            print("media-pause \(MediaPauseVersion.current)")
            return 0
        case .success(.setup):
            return runSetup()
        case .success(.status):
            return runStatus(paths: paths)
        case .success(.stop):
            return runStop(paths: paths)
        case .success(.action(let config)):
            return runAction(config, paths: paths)
        }
    }

    private static func runAction(_ config: ActionConfig, paths: TimerStatePaths) -> Int32 {
        let runner = SystemProcessRunner()
        let store = TimerStateStore(paths: paths)

        let browsers: [Browser]
        switch resolveBrowsers(config.browserTokens) {
        case .failure(let error):
            fputs("Error: \(error.message)\n", stderr)
            return 1
        case .success(let resolved):
            browsers = resolved
        }

        // Resume: run the engine immediately, then optionally count down to pause.
        if config.mode == .resume && !config.now {
            let engine = makeEngine(browsers: browsers, runner: runner).engine
            let results = engine.run(resume: true)
            let ok = renderResults(results, title: Report.title(for: .resume), boxWidth: isTTY() ? 62 : 62)
            store.writeLastResult(Report.summary(of: results))
            print("")
            if let duration = config.duration {
                guard ok else { return 1 }
                switch Duration.parse(duration) {
                case .failure(let error):
                    fputs("Error: \(errorDescription(error))\n", stderr)
                    return 1
                case .success(let seconds):
                    return runCountdown(totalSeconds: seconds, mode: .pause, browsers: browsers, runner: runner, store: store, notify: config.notify)
                }
            }
            return ok ? 0 : 1
        }

        // Immediate execution (--now).
        if config.now {
            return executeModeAction(mode: config.mode, browsers: browsers, runner: runner, store: store) ? 0 : 1
        }

        // Countdown then action.
        let durationString = config.duration ?? "1h"
        let seconds: Int
        switch Duration.parse(durationString) {
        case .failure(let error):
            fputs("Error: \(errorDescription(error))\n", stderr)
            return 1
        case .success(let value):
            seconds = value
        }
        return runCountdown(totalSeconds: seconds, mode: config.mode, browsers: browsers, runner: runner, store: store, notify: config.notify)
    }

    private static func errorDescription(_ error: DurationParseError) -> String {
        switch error {
        case .notPositive:
            return "Duration must be positive"
        case .invalid(let input):
            return "Invalid duration '\(input)'\n  Valid: 3600 | 1h | 30m | 1h30m | 2h15m30s"
        }
    }
}
