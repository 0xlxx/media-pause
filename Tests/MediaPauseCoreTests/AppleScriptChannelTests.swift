@testable import MediaPauseCore

private let testChrome = Browser.byKey("chrome")!

func testProbeScriptTargetsBrowser() throws {
    let script = AppleScriptScripts.probeScript(for: testChrome)
    try checkContains(script, "tell application \"Google Chrome\"")
    try checkContains(script, "1+1")
}

func testActionScriptEmbedsExpressionAndUsesMultilineIf() throws {
    let script = AppleScriptScripts.actionScript(for: testChrome, resume: false)
    try checkContains(script, MediaJS.pauseExpression)
    // multi-line if/else is required for AppleScript compilation with "&"
    try checkContains(script, "if acc is \"\" then\n")
    try checkContains(script, "else\n")
}

func testActionScriptResumeUsesResumeExpression() throws {
    let script = AppleScriptScripts.actionScript(for: testChrome, resume: true)
    try checkContains(script, MediaJS.resumeExpression)
}

func testMuteScript() throws {
    let script = AppleScriptScripts.muteScript(for: testChrome)
    try checkContains(script, "audible of t")
    try checkContains(script, "muted of t")
}

func testProbeEnabledThenPauseSucceeds() throws {
    let runner = FakeRunner()
    runner.stdout = "2"               // probe: 1+1 == 2
    let channel = AppleScriptChannel(browser: testChrome, runner: runner)
    _ = channel.apply(resume: false)  // warm cache with probe
    runner.stdout = "2:2"
    let result = channel.apply(resume: false)
    try checkTrue(result.ok)
    try checkEqual(result.affected, 2)
}

func testProbeDisabledReportsSetupHint() throws {
    let runner = FakeRunner()
    runner.stdout = "ERR"
    let channel = AppleScriptChannel(browser: testChrome, runner: runner)
    let result = channel.apply(resume: false)
    try checkFalse(result.ok)
    try checkContains(result.message, "setup")
}

func testPauseCountsMediaElements() throws {
    let runner = FakeRunner()
    runner.stdout = "2"
    let channel = AppleScriptChannel(browser: testChrome, runner: runner)
    _ = channel.apply(resume: false)
    runner.stdout = "3:4+0:1"
    let result = channel.apply(resume: false)
    try checkTrue(result.ok)
    try checkEqual(result.affected, 3)
    try checkContains(result.message, "paused 3 media elements")
}

func testResumeCounts() throws {
    let runner = FakeRunner()
    runner.stdout = "2"
    let channel = AppleScriptChannel(browser: testChrome, runner: runner)
    _ = channel.apply(resume: true)
    runner.stdout = "1:1"
    let result = channel.apply(resume: true)
    try checkTrue(result.ok)
    try checkEqual(result.affected, 1)
    try checkContains(result.message, "resumed 1 media element")
}

func testNoMediaFoundIsNotSuccess() throws {
    let runner = FakeRunner()
    runner.stdout = "2"
    let channel = AppleScriptChannel(browser: testChrome, runner: runner)
    _ = channel.apply(resume: false)
    runner.stdout = "0:0"
    let result = channel.apply(resume: false)
    try checkFalse(result.ok)
    try checkContains(result.message, "no media elements found")
}

func testJavaScriptErrorReported() throws {
    let runner = FakeRunner()
    runner.stdout = "2"
    let channel = AppleScriptChannel(browser: testChrome, runner: runner)
    _ = channel.apply(resume: false)
    runner.stdout = "ERR"
    runner.stderr = "execution error: Apple Events returned an error"
    let result = channel.apply(resume: false)
    try checkFalse(result.ok)
    try checkContains(result.message, "Apple Events returned an error")
}

func testProbeCached() throws {
    let runner = FakeRunner()
    runner.stdout = "2"
    let channel = AppleScriptChannel(browser: testChrome, runner: runner)
    _ = channel.apply(resume: false)      // probe + action = 2 invocations
    try checkEqual(runner.invocations.count, 2)
    _ = channel.apply(resume: false)      // probe must NOT run again
    try checkEqual(runner.invocations.count, 3)
}

// MARK: - Mute

func testMuteSucceeds() throws {
    let runner = FakeRunner()
    runner.stdout = "3:10"
    let channel = MuteChannel(browser: testChrome, runner: runner)
    let result = channel.apply(resume: false)
    try checkTrue(result.ok)
    try checkEqual(result.affected, 3)
    try checkContains(result.message, "muted 3 of 10 audible tabs")
}

func testMuteNothingMuted() throws {
    let runner = FakeRunner()
    runner.stdout = "0:5"
    let channel = MuteChannel(browser: testChrome, runner: runner)
    let result = channel.apply(resume: false)
    try checkFalse(result.ok)
}

func testMuteFailureSurfacesError() throws {
    let runner = FakeRunner()
    runner.stdout = ""
    runner.stderr = "audible/muted properties unavailable"
    let channel = MuteChannel(browser: testChrome, runner: runner)
    let result = channel.apply(resume: false)
    try checkFalse(result.ok)
    try checkContains(result.message, "unavailable")
}
