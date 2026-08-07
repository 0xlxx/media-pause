@testable import MediaPauseCore

func testDurationPlainSeconds() throws {
    try checkEqual(try Duration.parse("3600").get(), 3600)
    try checkEqual(try Duration.parse("1").get(), 1)
}

func testDurationHumanFormats() throws {
    try checkEqual(try Duration.parse("1h").get(), 3600)
    try checkEqual(try Duration.parse("30m").get(), 1800)
    try checkEqual(try Duration.parse("1h30m").get(), 5400)
    try checkEqual(try Duration.parse("2h15m30s").get(), 8130)
    try checkEqual(try Duration.parse("90m").get(), 5400)
    try checkEqual(try Duration.parse("45s").get(), 45)
}

func testDurationWhitespaceTolerated() throws {
    try checkEqual(try Duration.parse(" 30m ").get(), 1800)
}

func testDurationInvalidInputs() throws {
    try checkThrowsError { try Duration.parse("").get() }
    try checkThrowsError { try Duration.parse("abc").get() }
    try checkThrowsError { try Duration.parse("1h30").get() }      // trailing bare number
    try checkThrowsError { try Duration.parse("30x").get() }       // unknown suffix
    try checkThrowsError { try Duration.parse("h").get() }         // suffix without number
    try checkThrowsError { try Duration.parse("1h30m30").get() }   // trailing number
}

func testDurationNonPositiveRejected() throws {
    try checkThrowsError { try Duration.parse("0").get() }
    try checkThrowsError { try Duration.parse("-5").get() }
    try checkThrowsError { try Duration.parse("0m").get() }
}

func testFormatHMS() throws {
    try checkEqual(Duration.formatHMS(0), "00:00:00")
    try checkEqual(Duration.formatHMS(59), "00:00:59")
    try checkEqual(Duration.formatHMS(60), "00:01:00")
    try checkEqual(Duration.formatHMS(3661), "01:01:01")
    try checkEqual(Duration.formatHMS(8130), "02:15:30")
    try checkEqual(Duration.formatHMS(-10), "00:00:00")
}
