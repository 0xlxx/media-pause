@testable import MediaPauseCore

private func reportResult(_ channel: String, ok: Bool, affected: Int = 0, message: String = "m", target: String = "Chrome") -> ChannelResult {
    ChannelResult(channel: channel, target: target, ok: ok, affected: affected, message: message)
}

func testReportTitlePerMode() throws {
    try checkEqual(Report.title(for: .pause), "⏸  Pause Media")
    try checkEqual(Report.title(for: .resume), "▶  Resume Media")
    try checkEqual(Report.title(for: .playpause), "⏯  Play/Pause")
    try checkEqual(Report.title(for: .mute), "🔇  Mute Tabs")
    try checkEqual(Report.title(for: .quit), "🚫  Quit Browser")
}

func testReportLineFormats() throws {
    try checkEqual(Report.line(for: reportResult("js", ok: true, message: "paused 2 media elements")),
                   "✓ Chrome: paused 2 media elements")
    try checkEqual(Report.line(for: reportResult("js", ok: false, message: "no media")),
                   "⚠ Chrome: no media")
    try checkEqual(Report.line(for: reportResult("key", ok: true, message: "media key sent")),
                   "⇥ Chrome: media key sent")
    try checkEqual(Report.line(for: reportResult("engine", ok: false, message: "Could not pause")),
                   "✗ Could not pause")
}

func testReportSummarySuccess() throws {
    let summary = Report.summary(of: [reportResult("js", ok: true), reportResult("key", ok: false)])
    try checkTrue(summary.hasPrefix("SUCCESS"))
    try checkContains(summary, "OK js:Chrome")
    try checkContains(summary, "FAIL key:Chrome")
}

func testReportSummaryFailure() throws {
    let summary = Report.summary(of: [reportResult("js", ok: false)])
    try checkTrue(summary.hasPrefix("FAILED"))
}
