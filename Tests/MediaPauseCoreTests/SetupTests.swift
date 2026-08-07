@testable import MediaPauseCore
import Foundation

private func writePreferences(dir: URL, profile: String, json: [String: Any]) throws {
    let profileDir = dir.appendingPathComponent(profile)
    try FileManager.default.createDirectory(at: profileDir, withIntermediateDirectories: true)
    let data = try JSONSerialization.data(withJSONObject: json)
    try data.write(to: profileDir.appendingPathComponent("Preferences"))
}

private func readFlag(dir: URL, profile: String) -> Bool? {
    let path = dir.appendingPathComponent("\(profile)/Preferences").path
    let json = PreferencesEditor.readJSON(at: path)
    return (json?["browser"] as? [String: Any])?["allow_javascript_apple_events"] as? Bool
}

func testPreferencesEnablesFlagInAllProfiles() throws {
    try withTempDir { dir in
        try writePreferences(dir: dir, profile: "Default", json: ["browser": [:]])
        try writePreferences(dir: dir, profile: "Profile 1", json: ["browser": [:]])
        try writePreferences(dir: dir, profile: "Profile 2", json: ["browser": ["allow_javascript_apple_events": false]])

        let (fixed, total) = PreferencesEditor.enableJavaScriptFromAppleEvents(userDataDir: dir.path)
        try checkEqual(fixed, 3)
        try checkEqual(total, 3)

        for profile in ["Default", "Profile 1", "Profile 2"] {
            try checkEqual(readFlag(dir: dir, profile: profile), true, "profile \(profile)")
        }
    }
}

func testPreferencesAlreadyEnabledSkipped() throws {
    try withTempDir { dir in
        try writePreferences(dir: dir, profile: "Default", json: ["browser": ["allow_javascript_apple_events": true]])
        let (fixed, total) = PreferencesEditor.enableJavaScriptFromAppleEvents(userDataDir: dir.path)
        try checkEqual(fixed, 0)
        try checkEqual(total, 1)
    }
}

func testPreferencesMissingIgnored() throws {
    try withTempDir { dir in
        let (fixed, total) = PreferencesEditor.enableJavaScriptFromAppleEvents(userDataDir: dir.path)
        try checkEqual(fixed, 0)
        try checkEqual(total, 0)
    }
}

func testPreferencesNonexistentDirReturnsZero() throws {
    let (fixed, total) = PreferencesEditor.enableJavaScriptFromAppleEvents(userDataDir: "/nonexistent/\(UUID().uuidString)")
    try checkEqual(fixed, 0)
    try checkEqual(total, 0)
}

func testPreferencesNonProfileDirectoriesIgnored() throws {
    try withTempDir { dir in
        try writePreferences(dir: dir, profile: "Default", json: ["browser": [:]])
        try writePreferences(dir: dir, profile: "Other", json: ["browser": [:]])
        let (fixed, total) = PreferencesEditor.enableJavaScriptFromAppleEvents(userDataDir: dir.path)
        try checkEqual(fixed, 1)
        try checkEqual(total, 1)
    }
}

func testCustomUserDataDirsExtraction() throws {
    let ps = """
    /Applications/Google Chrome.app/Contents/MacOS/Google Chrome --user-data-dir=/tmp/chrome-test --enable-automation
    /usr/bin/someother
    /Applications/Safari.app/Contents/MacOS/Safari
    """
    try checkEqual(ChromeDiscovery.customUserDataDirs(processList: ps), ["/tmp/chrome-test"])
}

func testCustomUserDataDirsNoChromeLines() throws {
    try checkTrue(ChromeDiscovery.customUserDataDirs(processList: "nothing here").isEmpty)
    try checkTrue(ChromeDiscovery.customUserDataDirs(processList: "").isEmpty)
}

func testAutomationArgsDetection() throws {
    try checkTrue(AutomationArgs.isAutomation("Google Chrome --user-data-dir=/tmp/x --enable-automation"))
    try checkTrue(AutomationArgs.isAutomation("Google Chrome --remote-debugging-pipe about:blank"))
    try checkTrue(AutomationArgs.isAutomation("Google Chrome --remote-debugging-port=9222"))
    try checkTrue(AutomationArgs.isAutomation("Google Chrome --user-data-dir=/tmp/x"))
    try checkFalse(AutomationArgs.isAutomation("Google Chrome"))
    try checkFalse(AutomationArgs.isAutomation("Google Chrome --profile-directory=Default"))
    try checkFalse(AutomationArgs.isAutomation(""))
}
