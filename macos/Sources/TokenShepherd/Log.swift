import os

extension Logger {
    /// The app's log. Not NSLog: the unified log redacts NSLog text to "<private>", which hid
    /// every failure reason. Interpolate details with `privacy: .public` — never a token. Read
    /// (full path: in zsh, bare `log` is a builtin):
    /// /usr/bin/log show --predicate 'subsystem == "com.tokenshepherd.app"' --last 1d
    static let shepherd = Logger(subsystem: "com.tokenshepherd.app", category: "app")
}
