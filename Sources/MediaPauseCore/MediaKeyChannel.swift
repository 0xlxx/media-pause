import AppKit
import CoreGraphics
import Darwin

/// MediaRemote private framework — the same API Control Center uses.
public enum MediaRemote {
    public static let togglePlayPause: UInt32 = 2 // kMRTogglePlayPause

    private typealias SendCommandFn = @convention(c) (UInt32, AnyObject?) -> Bool
    private typealias GetNowPlayingInfoFn = @convention(c) (DispatchQueue, @escaping @convention(block) (NSDictionary?) -> Void) -> Void

    public static func sendCommand(_ command: UInt32) -> Bool {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW),
              let sym = dlsym(handle, "MRMediaRemoteSendCommand") else { return false }
        let fn = unsafeBitCast(sym, to: SendCommandFn.self)
        return fn(command, nil)
    }

    public static func hasNowPlayingSession() -> Bool {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW),
              let sym = dlsym(handle, "MRMediaRemoteGetNowPlayingInfo") else { return false }
        let fn = unsafeBitCast(sym, to: GetNowPlayingInfoFn.self)
        let semaphore = DispatchSemaphore(value: 0)
        var found = false
        fn(DispatchQueue(label: "media-pause.mr")) { info in
            if let info, info.count > 0 { found = true }
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 1.5)
        return found
    }
}

/// Posts a hardware play/pause key (virtual key 0x64) directly to each running
/// instance of the target browser via `CGEvent.postToPid`.
public final class MediaKeyChannel: MediaChannel {
    private let browser: Browser
    private let instances: () -> [NSRunningApplication]
    private let hasNowPlaying: () -> Bool

    public init(browser: Browser,
                instances: @escaping () -> [NSRunningApplication],
                hasNowPlaying: @escaping () -> Bool = { true }) {
        self.browser = browser
        self.instances = instances
        self.hasNowPlaying = hasNowPlaying
    }

    public var channelName: String { "key" }
    public var targetLabel: String { browser.displayName }

    public func apply(resume: Bool) -> ChannelResult {
        var anySent = false
        for app in instances() {
            if Self.postMediaKey(to: app) { anySent = true }
        }
        if anySent {
            // A posted media key only has an effect when the browser actually
            // owns a Now Playing session; claiming success otherwise is a lie.
            if hasNowPlaying() {
                return ChannelResult(channel: channelName, target: targetLabel, ok: true, affected: 0,
                                     message: "media key sent to \(browser.displayName)")
            }
            return ChannelResult(channel: channelName, target: targetLabel, ok: false, affected: 0,
                                 message: "media key sent but no Now Playing session — may not have taken effect")
        }
        return ChannelResult(channel: channelName, target: targetLabel, ok: false, affected: 0,
                             message: "\(browser.displayName) is not running")
    }

    public static func postMediaKey(to app: NSRunningApplication) -> Bool {
        let source = CGEventSource(stateID: .privateState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0x64, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0x64, keyDown: false) else { return false }
        down.postToPid(app.processIdentifier)
        usleep(50_000)
        up.postToPid(app.processIdentifier)
        return true
    }
}

/// System-wide media key via MediaRemote. Used only as the engine fallback so
/// a successful precise channel is never undone by a toggle.
public final class SystemMediaKeyChannel: MediaChannel {
    private let hasNowPlaying: () -> Bool
    private let send: () -> Bool

    public init(hasNowPlaying: @escaping () -> Bool, send: @escaping () -> Bool) {
        self.hasNowPlaying = hasNowPlaying
        self.send = send
    }

    public var channelName: String { "system-key" }
    public var targetLabel: String { "System" }

    public func apply(resume: Bool) -> ChannelResult {
        guard hasNowPlaying() else {
            return ChannelResult(channel: channelName, target: targetLabel, ok: false, affected: 0,
                                 message: "no Now Playing session")
        }
        if send() {
            return ChannelResult(channel: channelName, target: targetLabel, ok: true, affected: 0,
                                 message: "system media key sent (Now Playing session)")
        }
        return ChannelResult(channel: channelName, target: targetLabel, ok: false, affected: 0,
                             message: "failed to send system media key")
    }
}
