import Foundation

/// Enables `allow_javascript_apple_events` in Chrome profile Preferences
/// files. Pure file surgery — no Chrome restart required (the flag is picked
/// up by running instances on next AppleEvent; the menu-click live toggle is
/// handled by the app layer as a best-effort complement).
public enum PreferencesEditor {
    /// Scans a Chrome user-data dir for profiles and enables the flag.
    /// Returns `(fixed, total)` where `total` counts profiles whose
    /// Preferences file was readable and `fixed` counts profiles actually
    /// changed.
    public static func enableJavaScriptFromAppleEvents(userDataDir: String) -> (fixed: Int, total: Int) {
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: userDataDir) else {
            return (0, 0)
        }
        let profiles = items.filter { $0 == "Default" || $0.hasPrefix("Profile") }.sorted()

        var fixed = 0
        var total = 0
        for profile in profiles {
            let prefPath = (userDataDir as NSString).appendingPathComponent(profile).appending("/Preferences")
            guard var json = readJSON(at: prefPath) else { continue }
            total += 1
            var browser = json["browser"] as? [String: Any] ?? [:]
            if browser["allow_javascript_apple_events"] as? Bool == true { continue }
            browser["allow_javascript_apple_events"] = true
            json["browser"] = browser
            if writeJSON(json, to: prefPath) { fixed += 1 }
        }
        return (fixed, total)
    }

    public static func readJSON(at path: String) -> [String: Any]? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json
    }

    public static func writeJSON(_ json: [String: Any], to path: String) -> Bool {
        guard let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) else { return false }
        do {
            try data.write(to: URL(fileURLWithPath: path))
            return true
        } catch {
            return false
        }
    }
}

/// True when a process's command line marks it as a testing/automation
/// instance (custom profile, debug pipe/port, ...). Such instances must not
/// be the AppleScript routing target — they have no windows and break JS
/// injection — and they are quit before the JS channel runs.
public enum AutomationArgs {
    public static func isAutomation(_ args: String) -> Bool {
        args.contains("--enable-automation")
            || args.contains("--remote-debugging-pipe")
            || args.contains("--remote-debugging-port")
            || args.contains("--user-data-dir")
    }
}

/// Locates running Chrome user-data dirs (default + any `--user-data-dir`).
public enum ChromeDiscovery {
    public static func defaultUserDataDir() -> String {
        NSHomeDirectory() + "/Library/Application Support/Google/Chrome"
    }

    public static func customUserDataDirs(processList: String) -> Set<String> {
        var dirs: Set<String> = []
        for line in processList.split(separator: "\n") {
            guard line.contains("/Google Chrome") || line.contains("/Chromium") else { continue }
            let parts = line.components(separatedBy: "--user-data-dir=")
            guard parts.count > 1 else { continue }
            let dir = parts[1].components(separatedBy: " ").first ?? ""
            if !dir.isEmpty { dirs.insert(dir) }
        }
        return dirs
    }
}
