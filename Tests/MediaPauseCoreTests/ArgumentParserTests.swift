@testable import MediaPauseCore

private func parse(_ args: [String]) throws -> Command {
    switch Arguments.parse(args) {
    case .success(let command): return command
    case .failure(let error): throw error
    }
}

private func modeOf(_ args: [String]) throws -> Mode {
    let command = try parse(args)
    guard case .action(let config) = command else { throw TestFailure("expected action command") }
    return config.mode
}

func actionOf(_ args: [String]) throws -> ActionConfig {
    let command = try parse(args)
    guard case .action(let config) = command else { throw TestFailure("expected action command") }
    return config
}

func testSpecialCommands() throws {
    try checkEqual(try parse(["-h"]), .help)
    try checkEqual(try parse(["--help"]), .help)
    try checkEqual(try parse(["help"]), .help)
    try checkEqual(try parse(["-V"]), .version)
    try checkEqual(try parse(["--version"]), .version)
    try checkEqual(try parse(["version"]), .version)
    try checkEqual(try parse(["setup"]), .setup)
    try checkEqual(try parse(["--fix-perms"]), .setup)
    try checkEqual(try parse(["status"]), .status)
    try checkEqual(try parse(["stop"]), .stop)
}

func testDefaultAction() throws {
    let config = try actionOf([])
    try checkEqual(config.mode, .pause)
    try checkTrue(config.browserTokens.isEmpty)
    try checkNil(config.duration)
    try checkFalse(config.now)
}

func testDurationPositional() throws {
    let config = try actionOf(["45m"])
    try checkEqual(config.duration, "45m")
    try checkEqual(config.mode, .pause)
}

func testModes() throws {
    try checkEqual(try modeOf(["-r"]), .resume)
    try checkEqual(try modeOf(["--resume"]), .resume)
    try checkEqual(try modeOf(["-p"]), .playpause)
    try checkEqual(try modeOf(["--playpause"]), .playpause)
    try checkEqual(try modeOf(["-m"]), .mute)
    try checkEqual(try modeOf(["-q"]), .quit)
    try checkEqual(try modeOf(["--quit"]), .quit)
}

func testNowFlag() throws {
    let config = try actionOf(["--now"])
    try checkTrue(config.now)
}

func testBrowserFlags() throws {
    let config = try actionOf(["-b", "chrome,brave", "-b", "edge", "30m"])
    try checkEqual(config.browserTokens, ["chrome,brave", "edge"])
    try checkEqual(config.duration, "30m")
}

func testMissingBrowserValueFails() throws {
    try checkThrowsError { try parse(["-b"]) }
}

func testUnknownOptionFails() throws {
    try checkThrowsError { try parse(["--nope"]) }
    try checkThrowsError { try parse(["-x"]) }
}

func testDuplicateDurationFails() throws {
    try checkThrowsError { try parse(["1h", "30m"]) }
}

// MARK: - Browser

func testBrowserByKey() throws {
    try checkEqual(Browser.byKey("chrome")?.bundleID, "com.google.Chrome")
    try checkNil(Browser.byKey("netscape"))
}

func testBrowserResolveSingle() throws {
    try checkEqual(Browser.resolve("chrome")?.map(\.key), ["chrome"])
}

func testBrowserResolveCommaAndDedupe() throws {
    try checkEqual(Browser.resolve("chrome,brave")?.map(\.key), ["chrome", "brave"])
    try checkEqual(Browser.resolve("chrome,chrome")?.map(\.key), ["chrome"])
}

func testBrowserResolveAll() throws {
    try checkEqual(Browser.resolve("all")?.map(\.key), Browser.all.map(\.key))
    try checkEqual(Browser.resolve("all")?.count, 7)
    try checkEqual(Browser.resolve("all,chrome")?.count, Browser.all.count)
}

func testBrowserResolveUnknownReturnsNil() throws {
    try checkNil(Browser.resolve("netscape"))
    try checkNil(Browser.resolve("chrome,netscape"))
    try checkNil(Browser.resolve(""))
}
