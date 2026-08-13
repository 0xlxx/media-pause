public enum HelpText {
    public static var text: String {
        let browserList = Browser.all.map { "  \($0.key.padding(toLength: 9, withPad: " ", startingAt: 0))\($0.displayName)" }.joined(separator: "\n")
        return """
        media-pause \(MediaPauseVersion.current) — pause/resume browser audio & video on a timer

        Usage: media-pause [options] [duration]

        Modes:
          (default)        Pause media on all browser tabs after countdown
          -r, --resume     Resume playback (optionally: play N then auto-pause)
          -p, --playpause  Send the system media play/pause key (any app)
          -m, --mute       Mute audible browser tabs after countdown
          -q, --quit       Quit the browser entirely after countdown

        Options:
          -b, --browser <name>  Target browser(s) (default: chrome)
                                Comma-separated: -b chrome,brave · All: -b all
          -n, --now             Execute immediately (skip countdown)
          --notify              Show a system notification with sound when the
                                countdown finishes (off by default)
          --no-notify           Explicitly disable the completion notification
          -h, --help            Show this help
          -V, --version         Show version

        Commands:
          status                Show the running timer's progress
          stop                  Stop the running timer
          setup                 Enable "Allow JavaScript from Apple Events"
                                in all Chrome profiles (a.k.a. --fix-perms)

        Supported browsers:
        \(browserList)

        Duration formats:
          3600          Seconds
          1h            Hours
          30m           Minutes
          1h30m         1 hour 30 minutes

        Channel chain (per browser):
          CDP (if Chrome runs with --remote-debugging-port)
          → JS pause/resume (needs "Allow JavaScript from Apple Events")
          → media key → system media key

        Examples:
          media-pause 45m            Pause Chrome media after 45 minutes
          media-pause --now          Pause Chrome media right now
          media-pause -r             Resume immediately
          media-pause -r 10s         Resume, then auto-pause after 10 seconds
          media-pause -b brave 30m   Pause Brave media after 30 minutes
          media-pause -b all 1h      Pause media in every installed browser

        During countdown: Space to pause/resume timer & media, Ctrl+C to cancel.
        """
    }
}
