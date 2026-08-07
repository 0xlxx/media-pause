@testable import MediaPauseCore
import Foundation

/// Controllable clock for deterministic countdown tests.
final class FakeClock: Clock {
    var time: TimeInterval = 1_000_000
    func now() -> TimeInterval { time }
}

/// Fake process runner: records invocations and replays canned output.
final class FakeRunner: ProcessRunning {
    var invocations: [String] = []
    var stdout = ""
    var stderr = ""

    func run(_ executable: String, _ arguments: [String], timeout: TimeInterval) -> (stdout: String, stderr: String) {
        invocations.append(executable + " " + arguments.joined(separator: " "))
        return (stdout, stderr)
    }
}

/// Fake CDP transport with scriptable targets/values.
final class FakeCDPTransport: CDPTransport {
    var targets: [CDPTarget] = []
    var evaluateResults: [String: String] = [:]
    var evaluatedExpressions: [String] = []

    func fetchTargets(port: Int) -> [CDPTarget] { targets }

    func evaluate(webSocketURL: String, expression: String, timeout: TimeInterval) -> String? {
        evaluatedExpressions.append(expression)
        return evaluateResults[webSocketURL]
    }
}

/// A channel whose behavior is fully scripted for engine tests.
final class FakeChannel: MediaChannel {
    let name: String
    let label: String
    var result: ChannelResult

    init(name: String, label: String, result: ChannelResult) {
        self.name = name
        self.label = label
        self.result = result
    }

    var channelName: String { name }
    var targetLabel: String { label }

    var applyCount = 0
    var lastResume: Bool?

    func apply(resume: Bool) -> ChannelResult {
        applyCount += 1
        lastResume = resume
        return result
    }
}

extension Result {
    func get() throws -> Success {
        switch self {
        case .success(let value): return value
        case .failure(let error): throw error
        }
    }
}

/// Creates a temp dir and removes it on exit.
func withTempDir(_ body: (URL) throws -> Void) throws {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("media-pause-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    try body(dir)
}
