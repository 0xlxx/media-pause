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
    var onUpdate: ((String, Bool) -> Void)?

    private let pidFile = "/tmp/media-pause.pid"
    private let statusFile = "/tmp/media-pause.status"

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        tick()
    }

    private func tick() {
        guard let pidRaw = try? String(contentsOfFile: pidFile, encoding: .utf8) else {
            setNotRunning()
            return
        }
        let pidFields = pidRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", omittingEmptySubsequences: true)
        guard pidFields.count >= 2,
              let pid = Int32(pidFields[0]),
              kill(pid, 0) == 0 else {
            setNotRunning()
            return
        }
        let pidInstance = String(pidFields[1])

        guard let raw = try? String(contentsOfFile: statusFile, encoding: .utf8) else {
            setNotRunning()
            return
        }
        let allParts = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", omittingEmptySubsequences: true)
        guard allParts.count >= 5 else { setNotRunning(); return }

        guard String(allParts.last!) == pidInstance else { setNotRunning(); return }

        let startTs = TimeInterval(allParts[0]) ?? 0
        let totalSec = TimeInterval(allParts[1]) ?? 0
        guard startTs > 0, totalSec > 0 else { setNotRunning(); return }

        let mode = String(allParts[2])
        let lbl = allParts[3..<(allParts.count - 1)].joined(separator: " ")

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

        onUpdate?(displayText, true)
    }

    private func setNotRunning() {
        isRunning = false
        displayText = ""
        modeLabel = ""
        label = ""
        remaining = ""
        elapsed = ""
        progress = 0
        onUpdate?("", false)
    }

    private func formatTime(_ sec: TimeInterval) -> String {
        let s = Int(max(sec, 0))
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    private func formatShort(_ sec: TimeInterval) -> String {
        let s = Int(max(sec, 0))
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
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
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var state: TimerState!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        state = TimerState()

        // Font matching system menu bar clock
        let menuBarFont = NSFont.menuBarFont(ofSize: 0)
        let monoFont = NSFont.monospacedDigitSystemFont(ofSize: menuBarFont.pointSize, weight: .regular)

        // Measure exact width of "00:00:00" for fixed-length status item
        let sampleText = "00:00:00" as NSString
        let textWidth = sampleText.size(withAttributes: [.font: monoFont]).width.rounded(.up)

        // Status item — hidden when idle, fixed width when running
        statusItem = NSStatusBar.system.statusItem(withLength: textWidth)
        if let button = statusItem.button {
            button.font = monoFont
            button.alignment = .center
            button.title = ""
        }
        statusItem.isVisible = false

        // Build menu
        menu = NSMenu()
        updateMenu()
        statusItem.menu = menu

        // Receive state updates
        state.onUpdate = { [weak self] text, running in
            if running {
                self?.statusItem.isVisible = true
                self?.statusItem.length = textWidth
                self?.statusItem.button?.title = text
            } else {
                self?.statusItem.isVisible = false
                self?.statusItem.button?.title = ""
            }
            self?.updateMenu()
        }
    }

    private func updateMenu() {
        menu.removeAllItems()

        if state.isRunning {
            let headerItem = NSMenuItem()
            headerItem.title = "\(modeIcon(state.modeLabel)) \(state.modeLabel) \u{00B7} \(state.label)"
            headerItem.isEnabled = false
            menu.addItem(headerItem)

            // Progress bar via a disabled item with a visual representation
            let barItem = NSMenuItem()
            let barW = 20
            let filled = Int(state.progress * Double(barW))
            let empty = barW - filled
            let bar = String(repeating: "\u{2588}", count: max(0, filled)) + String(repeating: "\u{2591}", count: max(0, empty))
            barItem.title = "\(bar) \(Int(state.progress * 100))%"
            barItem.isEnabled = false
            menu.addItem(barItem)

            menu.addItem(NSMenuItem.separator())

            let remainItem = NSMenuItem()
            remainItem.title = "Remaining   \(state.remaining)"
            remainItem.isEnabled = false
            menu.addItem(remainItem)

            let elapsedItem = NSMenuItem()
            elapsedItem.title = "Elapsed      \(state.elapsed)"
            elapsedItem.isEnabled = false
            menu.addItem(elapsedItem)

            menu.addItem(NSMenuItem.separator())

            let stopItem = NSMenuItem(title: "Stop Timer", action: #selector(stopAction), keyEquivalent: "")
            stopItem.target = self
            menu.addItem(stopItem)
        } else {
            let idleItem = NSMenuItem()
            idleItem.title = "No timer running"
            idleItem.isEnabled = false
            menu.addItem(idleItem)
        }

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func stopAction() {
        state.stopTimer()
    }

    @objc private func quitAction() {
        NSApplication.shared.terminate(nil)
    }

    private func modeIcon(_ mode: String) -> String {
        switch mode.lowercased() {
        case "pause":  return "\u{23F8}"
        case "resume": return "\u{25B6}"
        case "mute":   return "\u{1F507}"
        case "quit":   return "\u{23FB}"
        case "key":    return "\u{2328}"
        default:       return "\u{23F3}"
        }
    }
}

// MARK: - App

@main
struct CountdownTimerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
