@testable import MediaPauseCore

func testExpressionsAreAppleScriptEmbeddable() throws {
    try checkTrue(MediaJS.isAppleScriptEmbeddable(MediaJS.pauseExpression))
    try checkTrue(MediaJS.isAppleScriptEmbeddable(MediaJS.resumeExpression))
    try checkFalse(MediaJS.isAppleScriptEmbeddable("say \"hi\""))
}

func testActionExpressionSelection() throws {
    try checkEqual(MediaJS.actionExpression(resume: false), MediaJS.pauseExpression)
    try checkEqual(MediaJS.actionExpression(resume: true), MediaJS.resumeExpression)
}

func testPauseExpressionTargetsMediaElements() throws {
    try checkContains(MediaJS.pauseExpression, "querySelectorAll('video,audio')")
    try checkContains(MediaJS.pauseExpression, "data-media-pause")
    try checkContains(MediaJS.pauseExpression, "e.pause()")
}

func testResumeExpressionTargetsMarkedElements() throws {
    try checkContains(MediaJS.resumeExpression, "[data-media-pause]")
    try checkContains(MediaJS.resumeExpression, "e.play()")
    try checkContains(MediaJS.resumeExpression, "removeAttribute('data-media-pause')")
}

func testParseCountersSimple() throws {
    let parsed = MediaJS.parseCounters("2:3")
    try checkEqual(parsed.affected, 2)
    try checkEqual(parsed.found, 3)
}

func testParseCountersAccumulated() throws {
    let parsed = MediaJS.parseCounters("1:1+0:2+3:1")
    try checkEqual(parsed.affected, 4)
    try checkEqual(parsed.found, 4)
}

func testParseCountersSkipsErrors() throws {
    let parsed = MediaJS.parseCounters("1:1+ERR+2:1")
    try checkEqual(parsed.affected, 3)
    try checkEqual(parsed.found, 2)
}

func testParseCountersMalformedIgnored() throws {
    let parsed = MediaJS.parseCounters("not-a-counter+1:1")
    try checkEqual(parsed.affected, 1)
    try checkEqual(parsed.found, 1)
}

func testParseCountersEmpty() throws {
    let parsed = MediaJS.parseCounters("")
    try checkEqual(parsed.affected, 0)
    try checkEqual(parsed.found, 0)
}
