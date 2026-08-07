import Foundation

/// A page target discovered via the Chrome DevTools Protocol HTTP endpoint.
public struct CDPTarget: Equatable {
    public let id: String
    public let type: String
    public let title: String
    public let url: String
    public let webSocketDebuggerURL: String

    public init(id: String, type: String, title: String, url: String, webSocketDebuggerURL: String) {
        self.id = id
        self.type = type
        self.title = title
        self.url = url
        self.webSocketDebuggerURL = webSocketDebuggerURL
    }
}

/// Transport abstraction over the two CDP endpoints we use:
/// `GET /json` (target discovery) and `Runtime.evaluate` over a WebSocket.
public protocol CDPTransport {
    func fetchTargets(port: Int) -> [CDPTarget]
    func evaluate(webSocketURL: String, expression: String, timeout: TimeInterval) -> String?
}

/// Pure CDP protocol helpers (message building, response parsing, target
/// parsing, port probing) — all unit-testable without a real Chrome.
public enum CDP {
    /// Ports probed when no `--cdp-port` is given.
    public static let defaultPorts: [Int] = Array(9222...9232)

    public static func evaluateRequest(id: Int, expression: String) -> [String: Any] {
        [
            "id": id,
            "method": "Runtime.evaluate",
            "params": ["expression": expression, "returnByValue": true],
        ]
    }

    /// Extracts the `result.result.value` string from a `Runtime.evaluate`
    /// reply (outer `result` is the protocol wrapper, inner `result` is the
    /// returned RemoteObject).
    public static func parseEvaluateValue(_ message: [String: Any]) -> String? {
        guard let outer = message["result"] as? [String: Any],
              let remote = outer["result"] as? [String: Any],
              let value = remote["value"] as? String else { return nil }
        return value
    }

    public static func parseTargets(_ data: Data) -> [CDPTarget] {
        guard let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
        return array.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let type = dict["type"] as? String,
                  let ws = dict["webSocketDebuggerUrl"] as? String else { return nil }
            return CDPTarget(
                id: id,
                type: type,
                title: dict["title"] as? String ?? "",
                url: dict["url"] as? String ?? "",
                webSocketDebuggerURL: ws
            )
        }
    }

    public static func firstOpenPort(ports: [Int], probe: (Int) -> Bool) -> Int? {
        ports.first { probe($0) }
    }
}

/// Pauses/resumes media elements in every page target of a debugging-enabled
/// Chrome. Preferred over AppleScript: no Apple Events permission needed and
/// it can reach Web Audio / cross-origin scenarios the JS channel cannot.
public final class CDPChannel: MediaChannel {
    private let port: Int
    private let transport: CDPTransport
    private var targets: [CDPTarget]?

    public init(port: Int, transport: CDPTransport) {
        self.port = port
        self.transport = transport
    }

    public var channelName: String { "cdp" }
    public var targetLabel: String { "Chrome (CDP :\(port))" }

    public func apply(resume: Bool) -> ChannelResult {
        if targets == nil {
            targets = transport.fetchTargets(port: port).filter { $0.type == "page" }
        }
        guard let pages = targets, !pages.isEmpty else {
            return ChannelResult(channel: channelName, target: targetLabel, ok: false, affected: 0,
                                 message: "no page targets on port \(port)")
        }

        let expression = MediaJS.actionExpression(resume: resume)
        var affected = 0
        for page in pages {
            if let value = transport.evaluate(webSocketURL: page.webSocketDebuggerURL,
                                              expression: expression, timeout: 5) {
                affected += MediaJS.parseCounters(value).affected
            }
        }

        let verb = resume ? "resumed" : "paused"
        if affected > 0 {
            return ChannelResult(channel: channelName, target: targetLabel, ok: true, affected: affected,
                                 message: "\(verb) \(affected) media element\(affected == 1 ? "" : "s") across \(pages.count) page\(pages.count == 1 ? "" : "s")")
        }
        return ChannelResult(channel: channelName, target: targetLabel, ok: false, affected: 0,
                             message: "no media found across \(pages.count) page\(pages.count == 1 ? "" : "s")")
    }
}
