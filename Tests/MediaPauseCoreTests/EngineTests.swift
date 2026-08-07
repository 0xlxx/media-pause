@testable import MediaPauseCore

private func result(_ channel: String, ok: Bool, affected: Int = 0, message: String = "m") -> ChannelResult {
    ChannelResult(channel: channel, target: "t", ok: ok, affected: affected, message: message)
}

func testFirstSuccessStopsFallback() throws {
    let first = FakeChannel(name: "js", label: "Chrome", result: result("js", ok: true, affected: 3))
    let second = FakeChannel(name: "key", label: "Chrome", result: result("key", ok: false))
    let fallback = FakeChannel(name: "system-key", label: "System", result: result("system-key", ok: true))

    let engine = MediaEngine(channels: [first, second], fallback: fallback)
    let results = engine.run(resume: false)

    try checkEqual(results.count, 2)
    try checkEqual(fallback.applyCount, 0, "fallback must not fire when a channel succeeded")
}

func testAllFailThenFallbackFires() throws {
    let first = FakeChannel(name: "js", label: "Chrome", result: result("js", ok: false))
    let fallback = FakeChannel(name: "system-key", label: "System", result: result("system-key", ok: true))

    let engine = MediaEngine(channels: [first], fallback: fallback)
    let results = engine.run(resume: false)

    try checkEqual(fallback.applyCount, 1)
    try checkTrue(MediaEngine.anySuccess(results))
}

func testFallbackFailsAppendsHonestFailure() throws {
    let first = FakeChannel(name: "js", label: "Chrome", result: result("js", ok: false))
    let fallback = FakeChannel(name: "system-key", label: "System", result: result("system-key", ok: false))

    let engine = MediaEngine(channels: [first], fallback: fallback)
    let results = engine.run(resume: false)

    try checkEqual(results.count, 3)
    try checkFalse(MediaEngine.anySuccess(results))
    try checkContains(results.last?.message ?? "", "Could not pause")
}

func testNoFallbackAppendsHonestFailure() throws {
    let channel = FakeChannel(name: "js", label: "Chrome", result: result("js", ok: false))
    let engine = MediaEngine(channels: [channel])
    let results = engine.run(resume: false)

    try checkEqual(results.count, 2)
    try checkEqual(results.last?.channel, "engine")
}

func testResumeFailureMessage() throws {
    let channel = FakeChannel(name: "js", label: "Chrome", result: result("js", ok: false))
    let engine = MediaEngine(channels: [channel])
    let results = engine.run(resume: true)
    try checkContains(results.last?.message ?? "", "Could not resume")
}

func testAllChannelsRun() throws {
    let a = FakeChannel(name: "js", label: "Chrome", result: result("js", ok: false))
    let b = FakeChannel(name: "key", label: "Chrome", result: result("key", ok: false))
    let engine = MediaEngine(channels: [a, b])
    _ = engine.run(resume: false)
    try checkEqual(a.applyCount, 1)
    try checkEqual(b.applyCount, 1)
}

func testResumeFlagPropagated() throws {
    let channel = FakeChannel(name: "js", label: "Chrome", result: result("js", ok: false))
    let engine = MediaEngine(channels: [channel])
    _ = engine.run(resume: true)
    try checkEqual(channel.lastResume, true)
}
