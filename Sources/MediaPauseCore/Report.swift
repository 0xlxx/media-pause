/// Plain-text formatting of engine results (no ANSI escapes — the app layer
/// may colorize). Kept in Core so formatting is unit-testable.
public enum Report {
    public static func title(for mode: Mode) -> String {
        switch mode {
        case .pause:      return "⏸  Pause Media"
        case .resume:     return "▶  Resume Media"
        case .playpause:  return "⏯  Play/Pause"
        case .mute:       return "🔇  Mute Tabs"
        case .quit:       return "🚫  Quit Browser"
        }
    }

    public static func line(for result: ChannelResult) -> String {
        switch result.channel {
        case "cdp", "js":
            if result.ok {
                return "✓ \(result.target): \(result.message)"
            }
            return "⚠ \(result.target): \(result.message)"
        case "key", "system-key":
            return result.ok
                ? "⇥ \(result.target): \(result.message)"
                : "⚠ \(result.target): \(result.message)"
        case "engine":
            return "✗ \(result.message)"
        default:
            return result.ok
                ? "✓ \(result.target): \(result.message)"
                : "⚠ \(result.target): \(result.message)"
        }
    }

    /// Single-line summary for `/tmp/media-pause.last-result` and notifications.
    public static func summary(of results: [ChannelResult]) -> String {
        let ok = MediaEngine.anySuccess(results)
        let detail = results.map { "\($0.ok ? "OK" : "FAIL") \($0.channel):\($0.target)" }.joined(separator: " | ")
        return "\(ok ? "SUCCESS" : "FAILED") \(detail)"
    }
}
