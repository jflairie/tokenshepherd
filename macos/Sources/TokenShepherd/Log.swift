import os

extension Logger {
    /// The app's log. Not NSLog: the unified log redacts NSLog text to "<private>", which hid
    /// every failure reason. Interpolate details with `privacy: .public` — never a token. Read
    /// (full path: in zsh, bare `log` is a builtin):
    /// /usr/bin/log show --predicate 'subsystem == "com.tokenshepherd.app"' --last 1d
    static let shepherd = Logger(subsystem: "com.tokenshepherd.app", category: "app")

    /// The unified log cuts each message at ~1 KB and drops the rest (measured 2026-11-04:
    /// ~1,020 bytes kept), while a usage reply runs ~2.2 KB. Split text into parts that each
    /// fit, never inside a character, so a logged reply survives whole.
    static func parts(of text: String, maxBytes: Int = 800) -> [Substring] {
        var parts: [Substring] = []
        var start = text.startIndex
        var bytes = 0
        for i in text.indices {
            let size = text[i].utf8.count
            if bytes > 0, bytes + size > maxBytes {
                parts.append(text[start..<i])
                start = i
                bytes = 0
            }
            bytes += size
        }
        parts.append(text[start...])
        return parts
    }
}
