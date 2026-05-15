import SwiftUI
import AppKit

// MARK: - Timer State

final class TimerState: ObservableObject {
    @Published var isRunning = false
    @Published var displayText = ""
    @Published var modeLabel = ""
    @Published var label = ""
    @Published var remaining = ""
    @Published var elapsed = ""
    @Published var progress: Double = 0

    private var timer: Timer?

    private let pidFile = "/tmp/media-pause.pid"
    private let statusFile = "/tmp/media-pause.status"

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        tick()
    }

    private func tick() {
        guard let raw = try? String(contentsOfFile: statusFile, encoding: .utf8) else {
            setNotRunning()
            return
        }
        let allParts = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", omittingEmptySubsequences: true)

        guard allParts.count >= 5 else { setNotRunning(); return }
        let startTs = TimeInterval(allParts[0]) ?? 0
        let totalSec = TimeInterval(allParts[1]) ?? 0
        let mode = String(allParts[2])
        let pidStr = String(allParts.last!)
        let lbl = allParts[3..<(allParts.count - 1)].joined(separator: " ")

        guard startTs > 0, totalSec > 0 else { setNotRunning(); return }
        guard isPidAlive(pidStr) else { setNotRunning(); return }

        let now = Date().timeIntervalSince1970
        let elapsedSec = now - startTs
        let remainingSec = max(totalSec - elapsedSec, 0)

        modeLabel = mode
        label = lbl
        remaining = formatTime(remainingSec)
        elapsed = formatTime(elapsedSec)
        progress = totalSec > 0 ? min(elapsedSec / totalSec, 1.0) : 0
        displayText = formatShort(remainingSec)
        isRunning = true
    }

    private func setNotRunning() {
        isRunning = false
        displayText = ""
        modeLabel = ""
        label = ""
        remaining = ""
        elapsed = ""
        progress = 0
    }

    private func isPidAlive(_ pidStr: String) -> Bool {
        guard let pid = Int32(pidStr), pid > 0 else { return false }
        return kill(pid, 0) == 0
    }

    private func formatTime(_ sec: TimeInterval) -> String {
        let s = Int(max(sec, 0))
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    private func formatShort(_ sec: TimeInterval) -> String {
        let s = Int(max(sec, 0))
        if s >= 3600 {
            return String(format: "%d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
        }
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    func stopTimer() {
        guard let pidContent = try? String(contentsOfFile: pidFile, encoding: .utf8) else { return }
        let pidStr = pidContent.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ").first.map(String.init) ?? ""
        guard let pid = Int32(pidStr) else { return }
        kill(pid, SIGTERM)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            kill(pid, SIGKILL)
        }
        try? FileManager.default.removeItem(atPath: self.pidFile)
        try? FileManager.default.removeItem(atPath: self.statusFile)
        setNotRunning()
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

// MARK: - App

@main
struct CountdownTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var state = TimerState()

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(modeIcon(state.modeLabel))
                    Text("\(state.modeLabel) · \(state.label)")
                        .fontWeight(.semibold)
                }
                ProgressView(value: state.progress, total: 1.0)
                    .tint(progressColor)
                HStack {
                    Text("Remaining")
                    Spacer()
                    Text(state.remaining)
                        .monospacedDigit()
                        .fontWeight(.medium)
                }
                HStack {
                    Text("Elapsed")
                    Spacer()
                    Text(state.elapsed)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Divider()
                Button("Stop Timer") {
                    state.stopTimer()
                }
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(width: 200)
        } label: {
            if state.isRunning {
                Text("\(modeIcon(state.modeLabel)) \(state.displayText)")
                    .monospacedDigit()
            } else {
                Text("⏳")
            }
        }
        .menuBarExtraStyle(.menu)
    }

    private var progressColor: Color {
        if state.progress >= 0.9 { return .red }
        if state.progress >= 0.5 { return .yellow }
        return .accentColor
    }

    private func modeIcon(_ mode: String) -> String {
        switch mode.lowercased() {
        case "pause":  return "⏸"
        case "resume": return "▶"
        case "mute":   return "🔇"
        case "quit":   return "⏻"
        case "key":    return "⌨"
        default:       return "⏳"
        }
    }
}
