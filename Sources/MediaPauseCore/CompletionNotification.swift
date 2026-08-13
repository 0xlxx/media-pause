/// Completion notification content (pure — no side effects) and the
/// AppleScript snippet that posts it with a sound via Notification Center.
public enum CompletionNotification {
    public static func title(for mode: Mode) -> String {
        switch mode {
        case .pause:      return "⏸ 媒体已暂停"
        case .resume:     return "▶ 媒体已恢复"
        case .mute:       return "🔇 标签页已静音"
        case .quit:       return "🚫 浏览器已退出"
        case .playpause:  return "⏯ 媒体键已发送"
        }
    }

    public static func body(for mode: Mode, label: String) -> String {
        switch mode {
        case .pause:      return "已暂停 \(label) 的音视频"
        case .resume:     return "已恢复 \(label) 的音视频"
        case .mute:       return "已静音 \(label) 的发声标签页"
        case .quit:       return "已退出 \(label)"
        case .playpause:  return "已向系统发送播放/暂停键"
        }
    }

    /// Builds a `display notification` AppleScript snippet (Standard Additions)
    /// with a sound. Double quotes are escaped for safe embedding.
    public static func script(title: String, body: String, sound: String = "Glass") -> String {
        let t = title.replacingOccurrences(of: "\"", with: "\\\"")
        let b = body.replacingOccurrences(of: "\"", with: "\\\"")
        return "display notification \"\(b)\" with title \"\(t)\" sound name \"\(sound)\""
    }
}
