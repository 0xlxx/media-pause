import Foundation

public enum DurationParseError: Error, Equatable {
    case notPositive
    case invalid(String)
}

/// Duration parsing / formatting.
///
/// Accepts plain seconds (`3600`), and human formats such as
/// `1h`, `30m`, `1h30m`, `2h15m30s`. Components must appear in the
/// order hours, minutes, seconds.
public enum Duration {
    public static func parse(_ input: String) -> Result<Int, DurationParseError> {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .failure(.invalid(input)) }

        if let seconds = Int(trimmed) {
            guard seconds > 0 else { return .failure(.notPositive) }
            return .success(seconds)
        }

        var total = 0
        var matched = false
        var remaining = trimmed

        for (suffix, multiplier) in [("h", 3600), ("m", 60), ("s", 1)] {
            guard let range = remaining.range(of: #"^\d+\#(suffix)"#, options: .regularExpression) else { continue }
            let token = String(remaining[range])
            total += (Int(token.dropLast()) ?? 0) * multiplier
            remaining.removeSubrange(range)
            matched = true
        }

        guard matched, total > 0, remaining.isEmpty else {
            return .failure(.invalid(input))
        }
        return .success(total)
    }

    /// Formats seconds as `HH:MM:SS` (clamped to zero).
    public static func formatHMS(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
}
