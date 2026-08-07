/// A Chromium-based browser the tool can target.
public struct Browser: Equatable, Hashable {
    public let key: String            // CLI flag value: "chrome", "brave", ...
    public let displayName: String    // human readable: "Chrome"
    public let appleScriptName: String // `tell application "..."` name
    public let bundleID: String       // com.google.Chrome, ...

    public init(key: String, displayName: String, appleScriptName: String, bundleID: String) {
        self.key = key
        self.displayName = displayName
        self.appleScriptName = appleScriptName
        self.bundleID = bundleID
    }

    public static let all: [Browser] = [
        Browser(key: "chrome",   displayName: "Chrome",   appleScriptName: "Google Chrome",       bundleID: "com.google.Chrome"),
        Browser(key: "brave",    displayName: "Brave",    appleScriptName: "Brave Browser",        bundleID: "com.brave.Browser"),
        Browser(key: "edge",     displayName: "Edge",     appleScriptName: "Microsoft Edge",       bundleID: "com.microsoft.edgemac"),
        Browser(key: "arc",      displayName: "Arc",      appleScriptName: "Arc",                  bundleID: "company.thebrowser.Browser"),
        Browser(key: "chromium", displayName: "Chromium", appleScriptName: "Chromium",             bundleID: "org.chromium.Chromium"),
        Browser(key: "opera",    displayName: "Opera",    appleScriptName: "Opera",                bundleID: "com.operasoftware.Opera"),
        Browser(key: "vivaldi",  displayName: "Vivaldi",  appleScriptName: "Vivaldi",              bundleID: "com.vivaldi.Vivaldi"),
    ]

    public static func byKey(_ key: String) -> Browser? {
        all.first { $0.key == key }
    }

    /// Expands a comma-separated spec (including the pseudo-browser `all`)
    /// into concrete browsers. Returns `nil` when any token is unknown.
    public static func resolve(_ raw: String) -> [Browser]? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        var result: [Browser] = []
        var seen: Set<String> = []
        for token in trimmed.lowercased().split(separator: ",").map({ String($0).trimmingCharacters(in: .whitespaces) }) {
            if token == "all" {
                for b in all where seen.insert(b.key).inserted {
                    result.append(b)
                }
            } else if let b = byKey(token) {
                if seen.insert(b.key).inserted { result.append(b) }
            } else {
                return nil
            }
        }
        return result
    }
}
