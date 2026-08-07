/// JavaScript expressions used to pause/resume media elements, plus parsers
/// for the counters they return.
///
/// Both expressions are deliberately single-line and contain **no double
/// quotes** so they can be embedded inside AppleScript string literals
/// (`execute t javascript "…"`) and CDP `Runtime.evaluate` payloads safely.
public enum MediaJS {
    /// Pauses every `<video>/<audio>` element (including same-origin iframes).
    /// Marks paused elements with `data-media-pause` so a later resume can
    /// target exactly the elements this tool paused. Returns `paused:found`.
    public static let pauseExpression = "(function(){var p=0,f=0;function h(e){if(!e.paused&&!e.ended){f++;try{e.setAttribute('data-media-pause','1')}catch(_){}}try{e.pause();p++}catch(_){}}document.querySelectorAll('video,audio').forEach(h);document.querySelectorAll('iframe').forEach(function(x){try{var d=x.contentDocument;if(d)d.querySelectorAll('video,audio').forEach(h)}catch(_){}});return p+':'+f})()"

    /// Resumes elements previously paused via `pauseExpression` (they carry
    /// `data-media-pause`). Returns `resumed:found`.
    public static let resumeExpression = "(function(){var p=0,f=0;function h(e){if(e.paused){f++;try{e.play();p++}catch(_){}}e.removeAttribute('data-media-pause')}document.querySelectorAll('[data-media-pause]').forEach(h);document.querySelectorAll('iframe').forEach(function(x){try{var d=x.contentDocument;if(d)d.querySelectorAll('[data-media-pause]').forEach(h)}catch(_){}});return p+':'+f})()"

    public static func actionExpression(resume: Bool) -> String {
        resume ? resumeExpression : pauseExpression
    }

    /// Parses a per-tab `paused:found` accumulator joined with `+` (tabs that
    /// raised an AppleScript error are encoded as `ERR` and skipped).
    public static func parseCounters(_ input: String) -> (affected: Int, found: Int) {
        var affected = 0
        var found = 0
        for part in input.split(separator: "+") where !part.contains("ERR") {
            let kv = part.split(separator: ":")
            if kv.count == 2 {
                affected += Int(kv[0]) ?? 0
                found += Int(kv[1]) ?? 0
            }
        }
        return (affected, found)
    }

    /// True when the expression is safe to embed inside a double-quoted
    /// AppleScript string literal.
    public static func isAppleScriptEmbeddable(_ js: String) -> Bool {
        !js.contains("\"") && !js.contains("\n")
    }
}
