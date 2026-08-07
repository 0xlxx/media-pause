import Foundation

/// Injectable time source (tests use a controllable fake).
public protocol Clock {
    func now() -> TimeInterval
}

public struct SystemClock: Clock {
    public init() {}
    public func now() -> TimeInterval { Date().timeIntervalSince1970 }
}

/// A snapshot of the countdown at a given instant.
public struct TimerSnapshot: Equatable {
    public let remaining: TimeInterval
    public let elapsed: TimeInterval
    public let progress: Double   // 0...1
    public let isPaused: Bool
    public let finished: Bool
}

/// Pausable countdown state machine.
///
/// `elapsed` excludes paused time: pausing the timer freezes the countdown,
/// and resumed time resumes from where it left off. Pure logic with an
/// injectable clock, so it is fully unit-testable.
public final class CountdownTimer {
    private let total: TimeInterval
    private let clock: Clock
    private var startAt: TimeInterval?
    private var pauseStartedAt: TimeInterval?
    private var accumulatedPause: TimeInterval = 0
    private var cancelled = false

    public init(total: TimeInterval, clock: Clock) {
        self.total = max(0, total)
        self.clock = clock
    }

    public func start() {
        if startAt == nil { startAt = clock.now() }
    }

    public func snapshot() -> TimerSnapshot {
        guard let startAt else {
            return TimerSnapshot(remaining: total, elapsed: 0, progress: 0, isPaused: false, finished: false)
        }
        let now = clock.now()
        var pausedTime = accumulatedPause
        if let pauseStartedAt { pausedTime += now - pauseStartedAt }
        let elapsed = max(0, now - startAt - pausedTime)
        let remaining = max(0, total - elapsed)
        return TimerSnapshot(
            remaining: remaining,
            elapsed: elapsed,
            progress: total > 0 ? min(elapsed / total, 1.0) : 1.0,
            isPaused: pauseStartedAt != nil,
            finished: remaining <= 0
        )
    }

    /// Toggles the pause state; returns the new paused state.
    @discardableResult
    public func togglePause() -> Bool {
        if let pauseStartedAt {
            accumulatedPause += clock.now() - pauseStartedAt
            self.pauseStartedAt = nil
            return false
        } else {
            pauseStartedAt = clock.now()
            return true
        }
    }

    public func cancel() {
        cancelled = true
    }

    public var isCancelled: Bool { cancelled }
    public var isPaused: Bool { pauseStartedAt != nil }
}
