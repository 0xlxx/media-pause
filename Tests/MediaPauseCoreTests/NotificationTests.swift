@testable import MediaPauseCore

func testNotificationDefaultOff() throws {
    let config = try actionOf([])
    try checkFalse(config.notify, "notify 默认应关闭（显式 --notify 启用）")
    try checkFalse(try actionOf(["30m"]).notify)
}

func testNotificationFlags() throws {
    try checkTrue(try actionOf(["--notify"]).notify)
    try checkFalse(try actionOf(["--no-notify"]).notify)
    try checkTrue(try actionOf(["--no-notify", "--notify"]).notify)  // 后者覆盖前者
    try checkFalse(try actionOf(["--notify", "--no-notify"]).notify)
    try checkTrue(try actionOf(["--notify", "30m"]).notify)
    try checkFalse(try actionOf(["--no-notify", "30m"]).notify)
}

func testNotificationTitles() throws {
    try checkEqual(CompletionNotification.title(for: .pause), "⏸ 媒体已暂停")
    try checkEqual(CompletionNotification.title(for: .resume), "▶ 媒体已恢复")
    try checkEqual(CompletionNotification.title(for: .mute), "🔇 标签页已静音")
    try checkEqual(CompletionNotification.title(for: .quit), "🚫 浏览器已退出")
    try checkEqual(CompletionNotification.title(for: .playpause), "⏯ 媒体键已发送")
}

func testNotificationBodies() throws {
    try checkEqual(CompletionNotification.body(for: .pause, label: "Chrome"), "已暂停 Chrome 的音视频")
    try checkEqual(CompletionNotification.body(for: .resume, label: "Chrome"), "已恢复 Chrome 的音视频")
    try checkEqual(CompletionNotification.body(for: .mute, label: "Chrome"), "已静音 Chrome 的发声标签页")
    try checkEqual(CompletionNotification.body(for: .quit, label: "Chrome"), "已退出 Chrome")
    try checkEqual(CompletionNotification.body(for: .playpause, label: "Chrome"), "已向系统发送播放/暂停键")
}

func testNotificationScript() throws {
    let script = CompletionNotification.script(title: "⏸ 媒体已暂停", body: "已暂停 Chrome 的音视频")
    try checkContains(script, "display notification")
    try checkContains(script, "with title")
    try checkContains(script, "sound name \"Glass\"")
    try checkContains(script, "已暂停 Chrome 的音视频")
}

func testNotificationScriptEscapesQuotes() throws {
    let script = CompletionNotification.script(title: "say \"hi\"", body: "body")
    try checkContains(script, "\\\"")
    try checkFalse(script.contains("say \"")) // 裸引号不应出现
}
