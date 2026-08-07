@testable import MediaPauseCore
import Foundation

private func cdpTarget(_ identifier: String, ws: String? = nil) -> CDPTarget {
    let wsURL = ws ?? "ws://127.0.0.1:9222/devtools/page/\(identifier)"
    return CDPTarget(id: identifier, type: "page", title: "page-\(identifier)", url: "https://example.com/\(identifier)", webSocketDebuggerURL: wsURL)
}

// MARK: - Protocol helpers

func testEvaluateRequestShape() throws {
    let request = CDP.evaluateRequest(id: 7, expression: "1+1")
    try checkEqual(request["id"] as? Int, 7)
    try checkEqual(request["method"] as? String, "Runtime.evaluate")
    let params = request["params"] as? [String: Any]
    try checkEqual(params?["expression"] as? String, "1+1")
    try checkEqual(params?["returnByValue"] as? Bool, true)
}

func testParseEvaluateValue() throws {
    let reply: [String: Any] = [
        "id": 1,
        "result": ["result": ["type": "string", "value": "2:1"], "id": 1],
    ]
    try checkEqual(CDP.parseEvaluateValue(reply), "2:1")
}

func testParseEvaluateValueMissing() throws {
    try checkNil(CDP.parseEvaluateValue([:]))
    try checkNil(CDP.parseEvaluateValue(["result": [String: Any]()]))
}

func testParseTargets() throws {
    let json = """
    [
      {"id": "1", "type": "page", "title": "YouTube", "url": "https://youtube.com", "webSocketDebuggerUrl": "ws://127.0.0.1:9222/devtools/page/1"},
      {"id": "2", "type": "other", "title": "ext", "url": "chrome-extension://x", "webSocketDebuggerUrl": "ws://127.0.0.1:9222/devtools/page/2"},
      {"id": "3"}
    ]
    """
    let targets = CDP.parseTargets(Data(json.utf8))
    try checkEqual(targets.count, 2)
    try checkEqual(targets[0].type, "page")
    try checkEqual(targets[0].title, "YouTube")
    try checkEqual(targets[1].type, "other")
}

func testParseTargetsInvalidJSON() throws {
    try checkTrue(CDP.parseTargets(Data("not json".utf8)).isEmpty)
}

func testFirstOpenPort() throws {
    try checkEqual(CDP.firstOpenPort(ports: [9222, 9223, 9224], probe: { $0 == 9223 }), 9223)
    try checkNil(CDP.firstOpenPort(ports: [9222], probe: { _ in false }))
    try checkNil(CDP.firstOpenPort(ports: [], probe: { _ in true }))
}

// MARK: - CDPChannel

func testCDPPausesMediaAcrossPages() throws {
    let transport = FakeCDPTransport()
    transport.targets = [cdpTarget("1"), cdpTarget("2")]
    transport.evaluateResults = [
        "ws://127.0.0.1:9222/devtools/page/1": "2:2",
        "ws://127.0.0.1:9222/devtools/page/2": "1:1",
    ]
    let channel = CDPChannel(port: 9222, transport: transport)
    let result = channel.apply(resume: false)
    try checkTrue(result.ok)
    try checkEqual(result.affected, 3)
    try checkEqual(transport.evaluatedExpressions, [MediaJS.pauseExpression, MediaJS.pauseExpression])
}

func testCDPResumeUsesResumeExpression() throws {
    let transport = FakeCDPTransport()
    transport.targets = [cdpTarget("1")]
    transport.evaluateResults = ["ws://127.0.0.1:9222/devtools/page/1": "1:1"]
    let channel = CDPChannel(port: 9222, transport: transport)
    let result = channel.apply(resume: true)
    try checkTrue(result.ok)
    try checkEqual(transport.evaluatedExpressions, [MediaJS.resumeExpression])
}

func testCDPNoTargetsFails() throws {
    let transport = FakeCDPTransport()
    let channel = CDPChannel(port: 9222, transport: transport)
    let result = channel.apply(resume: false)
    try checkFalse(result.ok)
    try checkContains(result.message, "no page targets")
}

func testCDPNonPageTargetsIgnored() throws {
    let transport = FakeCDPTransport()
    transport.targets = [CDPTarget(id: "x", type: "other", title: "ext", url: "chrome-extension://x", webSocketDebuggerURL: "ws://x")]
    let channel = CDPChannel(port: 9222, transport: transport)
    let result = channel.apply(resume: false)
    try checkFalse(result.ok)
    try checkContains(result.message, "no page targets")
}

func testCDPNoMediaFoundIsNotSuccess() throws {
    let transport = FakeCDPTransport()
    transport.targets = [cdpTarget("1")]
    transport.evaluateResults = ["ws://127.0.0.1:9222/devtools/page/1": "0:0"]
    let channel = CDPChannel(port: 9222, transport: transport)
    let result = channel.apply(resume: false)
    try checkFalse(result.ok)
    try checkContains(result.message, "no media found")
}
