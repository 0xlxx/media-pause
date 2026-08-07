import Foundation

/// Abstraction over launching external processes (osascript, ps, ...) so
/// channels can be tested with fakes.
public protocol ProcessRunning {
    func run(_ executable: String, _ arguments: [String], timeout: TimeInterval) -> (stdout: String, stderr: String)
}

/// Real `Process`-based runner with a hard timeout.
public struct SystemProcessRunner: ProcessRunning {
    public init() {}

    public func run(_ executable: String, _ arguments: [String], timeout: TimeInterval) -> (stdout: String, stderr: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe

        final class Buffer {
            var data = Data()
        }
        let outBuffer = Buffer()
        let errBuffer = Buffer()
        let semaphore = DispatchSemaphore(value: 0)
        var open = 2
        let lock = NSLock()

        func attach(_ handle: FileHandle, _ buffer: Buffer) {
            handle.readabilityHandler = { handler in
                let data = handler.availableData
                if data.isEmpty {
                    handler.readabilityHandler = nil
                    lock.lock()
                    open -= 1
                    let done = open == 0
                    lock.unlock()
                    if done { semaphore.signal() }
                } else {
                    buffer.data.append(data)
                }
            }
        }
        attach(outPipe.fileHandleForReading, outBuffer)
        attach(errPipe.fileHandleForReading, errBuffer)

        try? task.run()
        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            task.terminate()
        }
        try? outPipe.fileHandleForReading.close()
        try? errPipe.fileHandleForReading.close()
        return (String(data: outBuffer.data, encoding: .utf8) ?? "",
                String(data: errBuffer.data, encoding: .utf8) ?? "")
    }
}

/// Pure builders for the AppleScript snippets used by the JS channel.
public enum AppleScriptScripts {
    /// Cheap probe: does `execute javascript` work in this browser?
    public static func probeScript(for browser: Browser) -> String {
        """
        tell application "\(browser.appleScriptName)"
        try
        set r to execute active tab of window 1 javascript "1+1"
        return "" & r
        on error
        return "ERR"
        end try
        end tell
        """
    }

    /// Runs the pause/resume expression against every tab of every window and
    /// accumulates `paused:found` counters joined with `+`.
    ///
    /// NOTE: the if/else must be multi-line — AppleScript's one-line
    /// `if … then … else` fails to compile when the else clause contains `&`
    /// concatenation, which silently disabled the channel in older versions.
    public static func actionScript(for browser: Browser, resume: Bool) -> String {
        let js = MediaJS.actionExpression(resume: resume)
        return """
        tell application "\(browser.appleScriptName)"
            set acc to ""
            repeat with w in windows
                try
                    repeat with t in tabs of w
                        try
                            set r to execute t javascript "\(js)"
                            if acc is "" then
                                set acc to r
                            else
                                set acc to acc & "+" & r
                            end if
                        on error
                            set acc to acc & "+ERR"
                        end try
                    end repeat
                end try
            end repeat
            return acc
        end tell
        """
    }
}

/// Pauses/resumes media elements via AppleScript JS injection.
///
/// Requires `View → Developer → Allow JavaScript from Apple Events` in the
/// browser; the channel probes once and caches the result.
public final class AppleScriptChannel: MediaChannel {
    private let browser: Browser
    private let runner: ProcessRunning
    private let activate: () -> Void
    private var jsEnabled: Bool?

    public init(browser: Browser, runner: ProcessRunning, activate: @escaping () -> Void = {}) {
        self.browser = browser
        self.runner = runner
        self.activate = activate
    }

    public var channelName: String { "js" }
    public var targetLabel: String { browser.displayName }

    public func apply(resume: Bool) -> ChannelResult {
        activate()
        if jsEnabled == nil {
            jsEnabled = probe()
        }
        guard jsEnabled == true else {
            return ChannelResult(channel: channelName, target: targetLabel, ok: false, affected: 0,
                                 message: "JS from Apple Events is OFF (run `media-pause setup`)")
        }

        let script = AppleScriptScripts.actionScript(for: browser, resume: resume)
        let (out, err) = runner.run("/usr/bin/osascript", ["-e", script], timeout: 8)

        if out.contains("ERR") && !out.contains(":") {
            if err.contains("JavaScript") {
                return ChannelResult(channel: channelName, target: targetLabel, ok: false, affected: 0,
                                     message: "JS from Apple Events is OFF (run `media-pause setup`)")
            }
            let detail = err.trimmingCharacters(in: .whitespacesAndNewlines)
            return ChannelResult(channel: channelName, target: targetLabel, ok: false, affected: 0,
                                 message: detail.isEmpty ? "AppleScript failed" : detail)
        }

        let (affected, found) = MediaJS.parseCounters(out)
        let verb = resume ? "resumed" : "paused"
        if affected > 0 {
            return ChannelResult(channel: channelName, target: targetLabel, ok: true, affected: affected,
                                 message: "\(verb) \(affected) media element\(affected == 1 ? "" : "s")")
        }
        if found > 0 {
            return ChannelResult(channel: channelName, target: targetLabel, ok: false, affected: 0,
                                 message: "\(resume ? "resume" : "pause") failed on \(found) element\(found == 1 ? "" : "s")")
        }
        return ChannelResult(channel: channelName, target: targetLabel, ok: false, affected: 0,
                             message: "no media elements found")
    }

    private func probe() -> Bool {
        activate()
        let script = AppleScriptScripts.probeScript(for: browser)
        let (out, _) = runner.run("/usr/bin/osascript", ["-e", script], timeout: 4)
        return out.contains("2") && !out.contains("ERR")
    }
}

/// Mutes audible tabs via the browser's native AppleScript dictionary
/// (no JS permission needed). Kept honest: newer Chrome versions (151+)
/// broke the `audible`/`muted` properties, which surfaces as an error.
extension AppleScriptScripts {
    public static func muteScript(for browser: Browser) -> String {
        """
        tell application "\(browser.appleScriptName)"
            set okCount to 0
            set totalTabs to 0
            if (count of windows) = 0 then
                return "0:0"
            end if
            repeat with w in windows
                try
                    repeat with t in tabs of w
                        try
                            set totalTabs to totalTabs + 1
                            if audible of t is true then
                                set muted of t to true
                                set okCount to okCount + 1
                            end if
                        end try
                    end repeat
                end try
            end repeat
            return okCount & ":" & totalTabs
        end tell
        """
    }
}

/// Mutes audible tabs in a browser. Reports `okCount:totalTabs`.
public final class MuteChannel: MediaChannel {
    private let browser: Browser
    private let runner: ProcessRunning

    public init(browser: Browser, runner: ProcessRunning) {
        self.browser = browser
        self.runner = runner
    }

    public var channelName: String { "mute" }
    public var targetLabel: String { browser.displayName }

    public func apply(resume: Bool) -> ChannelResult {
        let script = AppleScriptScripts.muteScript(for: browser)
        let (out, err) = runner.run("/usr/bin/osascript", ["-e", script], timeout: 8)
        let kv = out.split(separator: ":")
        guard kv.count == 2, let muted = Int(kv[0]), let total = Int(kv[1]) else {
            let detail = err.trimmingCharacters(in: .whitespacesAndNewlines)
            return ChannelResult(channel: channelName, target: targetLabel, ok: false, affected: 0,
                                 message: detail.isEmpty ? "mute failed" : detail)
        }
        return ChannelResult(channel: channelName, target: targetLabel, ok: muted > 0, affected: muted,
                             message: "muted \(muted) of \(total) audible tab\(total == 1 ? "" : "s")")
    }
}
