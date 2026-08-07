/// Result of one channel attempt. `ok` means the channel took effect;
/// `affected` counts media elements paused/resumed (0 when not applicable).
public struct ChannelResult: Equatable {
    public let channel: String   // "cdp" | "js" | "key" | "system-key" | "engine"
    public let target: String    // display label, e.g. "Chrome", "System"
    public let ok: Bool
    public let affected: Int
    public let message: String

    public init(channel: String, target: String, ok: Bool, affected: Int, message: String) {
        self.channel = channel
        self.target = target
        self.ok = ok
        self.affected = affected
        self.message = message
    }
}

/// One pausable/resumable channel.
public protocol MediaChannel {
    var channelName: String { get }
    var targetLabel: String { get }
    func apply(resume: Bool) -> ChannelResult
}

/// Runs channels in priority order and appends an honest failure line when
/// nothing succeeded. A fallback channel (e.g. system media key) only fires
/// when every earlier channel failed, so a successful precise channel never
/// gets undone by a system-wide toggle.
public final class MediaEngine {
    private let channels: [MediaChannel]
    private let fallback: MediaChannel?

    public init(channels: [MediaChannel], fallback: MediaChannel? = nil) {
        self.channels = channels
        self.fallback = fallback
    }

    public func run(resume: Bool) -> [ChannelResult] {
        var results: [ChannelResult] = []
        var anySuccess = false

        for channel in channels {
            let result = channel.apply(resume: resume)
            results.append(result)
            if result.ok { anySuccess = true }
        }

        if !anySuccess, let fallback {
            let result = fallback.apply(resume: resume)
            results.append(result)
            if result.ok { anySuccess = true }
        }

        if !anySuccess {
            results.append(ChannelResult(
                channel: "engine",
                target: "all",
                ok: false,
                affected: 0,
                message: resume
                    ? "Could not resume: no media found and no Now Playing session"
                    : "Could not pause: no media elements found and no Now Playing session"
            ))
        }

        return results
    }

    public static func anySuccess(_ results: [ChannelResult]) -> Bool {
        results.contains { $0.ok }
    }
}
