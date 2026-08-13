/// Modes supported by the action command.
public enum Mode: String, Equatable, CaseIterable {
    case pause
    case resume
    case playpause
    case mute
    case quit
}

/// Argument parsing failure with a user-facing message.
public struct ArgumentError: Error, Equatable {
    public let message: String
    public init(_ message: String) {
        self.message = message
    }
}

/// Fully parsed command line.
public enum Command: Equatable {
    case help
    case version
    case setup
    case status
    case stop
    case action(ActionConfig)
}

public struct ActionConfig: Equatable {
    public var mode: Mode
    /// Raw browser tokens from `-b` (comma-separated specs allowed). Empty
    /// means "default to Chrome".
    public var browserTokens: [String]
    public var duration: String?
    public var now: Bool
    /// Whether to show a system notification (with sound) when the countdown
    /// finishes. Opt-in: enable with `--notify`.
    public var notify: Bool

    public init(mode: Mode = .pause, browserTokens: [String] = [], duration: String? = nil, now: Bool = false, notify: Bool = false) {
        self.mode = mode
        self.browserTokens = browserTokens
        self.duration = duration
        self.now = now
        self.notify = notify
    }
}

public enum Arguments {
    /// Parses CLI arguments. Returns a `Command`, or a user-facing error
    /// message on failure.
    public static func parse(_ args: [String]) -> Result<Command, ArgumentError> {
        var mode: Mode = .pause
        var browserTokens: [String] = []
        var duration: String?
        var now = false
        var notify = false

        var i = 0
        while i < args.count {
            let arg = args[i]
            switch arg {
            case "-h", "--help", "help":
                return .success(.help)
            case "-V", "--version", "version":
                return .success(.version)
            case "setup", "--fix-perms":
                return .success(.setup)
            case "status":
                return .success(.status)
            case "stop":
                return .success(.stop)
            case "-n", "--now":
                now = true
            case "--notify":
                notify = true
            case "--no-notify":
                notify = false
            case "-r", "--resume":
                mode = .resume
            case "-p", "--playpause":
                mode = .playpause
            case "-m", "--mute":
                mode = .mute
            case "-q", "--quit":
                mode = .quit
            case "-b", "--browser":
                i += 1
                guard i < args.count else { return .failure(ArgumentError("-b requires a browser name")) }
                browserTokens.append(args[i])
            default:
                if arg.hasPrefix("-") {
                    return .failure(ArgumentError("Unknown option '\(arg)'"))
                }
                guard duration == nil else {
                    return .failure(ArgumentError("Unexpected extra argument '\(arg)'"))
                }
                duration = arg
            }
            i += 1
        }
        return .success(.action(ActionConfig(mode: mode, browserTokens: browserTokens, duration: duration, now: now, notify: notify)))
    }
}
