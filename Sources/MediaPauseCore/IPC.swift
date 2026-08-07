import Foundation

/// Status record shared with the menu bar app and Raycast via `/tmp`.
///
/// Wire format (space separated, label may contain spaces, instanceID last):
///   `<startTs> <totalSeconds> <mode> <label...> <instanceID>`
public struct TimerStatus: Equatable {
    public let startTs: TimeInterval
    public let totalSeconds: Int
    public let mode: String
    public let label: String
    public let instanceID: String

    public init(startTs: TimeInterval, totalSeconds: Int, mode: String, label: String, instanceID: String) {
        self.startTs = startTs
        self.totalSeconds = totalSeconds
        self.mode = mode
        self.label = label
        self.instanceID = instanceID
    }

    public func encode() -> String {
        "\(Int(startTs)) \(totalSeconds) \(mode) \(label) \(instanceID)"
    }

    public static func decode(_ raw: String) -> TimerStatus? {
        let parts = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 5,
              let startTs = TimeInterval(parts[0]),
              let totalSeconds = Int(parts[1]) else { return nil }
        let mode = String(parts[2])
        let label = parts[3..<(parts.count - 1)].joined(separator: " ")
        let instanceID = String(parts.last!)
        return TimerStatus(startTs: startTs, totalSeconds: totalSeconds, mode: mode, label: label, instanceID: instanceID)
    }
}

/// PID record used to prove a timer is still alive.
///
/// Wire format: `<pid> <instanceID>`
public struct PidRecord: Equatable {
    public let pid: Int32
    public let instanceID: String

    public init(pid: Int32, instanceID: String) {
        self.pid = pid
        self.instanceID = instanceID
    }

    public func encode() -> String {
        "\(pid) \(instanceID)"
    }

    public static func decode(_ raw: String) -> PidRecord? {
        let parts = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2, let pid = Int32(parts[0]) else { return nil }
        return PidRecord(pid: pid, instanceID: String(parts[1]))
    }
}

/// Injectable file locations (tests can redirect away from `/tmp`).
public struct TimerStatePaths: Equatable {
    public let pidPath: String
    public let statusPath: String
    public let lastResultPath: String

    public init(pidPath: String = "/tmp/media-pause.pid",
                statusPath: String = "/tmp/media-pause.status",
                lastResultPath: String = "/tmp/media-pause.last-result") {
        self.pidPath = pidPath
        self.statusPath = statusPath
        self.lastResultPath = lastResultPath
    }
}

/// Reads/writes the timer state files. Paths are injectable for tests.
public final class TimerStateStore {
    public let paths: TimerStatePaths
    public let instanceID: String

    public init(paths: TimerStatePaths = TimerStatePaths(), instanceID: String = TimerStateStore.makeInstanceID()) {
        self.paths = paths
        self.instanceID = instanceID
    }

    public static func makeInstanceID() -> String {
        let now = Date().timeIntervalSince1970
        let micros = Int((now - floor(now)) * 1_000_000)
        return "\(Int(now))-\(micros)-\(getpid())"
    }

    public func start(pid: Int32, status: TimerStatus) {
        let record = PidRecord(pid: pid, instanceID: status.instanceID)
        try? record.encode().write(toFile: paths.pidPath, atomically: true, encoding: .utf8)
        try? status.encode().write(toFile: paths.statusPath, atomically: true, encoding: .utf8)
    }

    public func writeLastResult(_ summary: String) {
        try? summary.write(toFile: paths.lastResultPath, atomically: true, encoding: .utf8)
    }

    public func readPid() -> PidRecord? {
        guard let raw = try? String(contentsOfFile: paths.pidPath, encoding: .utf8) else { return nil }
        return PidRecord.decode(raw)
    }

    public func readStatus() -> TimerStatus? {
        guard let raw = try? String(contentsOfFile: paths.statusPath, encoding: .utf8) else { return nil }
        return TimerStatus.decode(raw)
    }

    /// Removes the pid/status files (called on completion/cancel/stop).
    public func clear() {
        try? FileManager.default.removeItem(atPath: paths.pidPath)
        try? FileManager.default.removeItem(atPath: paths.statusPath)
    }
}
