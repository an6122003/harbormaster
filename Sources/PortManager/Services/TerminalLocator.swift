import AppKit
import Foundation

enum TerminalRevealResult {
    case focusedTab
    /// We could only identify the owning app, not a specific window/tab. The
    /// caller decides whether to actually switch focus — finding this out
    /// shouldn't silently steal focus on its own.
    case foundApp(name: String, bundleIdentifier: String)
    case notFound
}

enum TerminalLocator {

    // Maps TERM_PROGRAM (a convention nearly every terminal/IDE terminal sets) to a
    // bundle ID, used only when __CFBundleIdentifier didn't already give us the
    // precise answer (e.g. it was stripped somewhere along the chain).
    private static let termProgramBundleIDs: [String: String] = [
        "Apple_Terminal": "com.apple.Terminal",
        "iTerm.app": "com.googlecode.iterm2",
        "vscode": "com.microsoft.VSCode",
        "WarpTerminal": "dev.warp.Warp-Stable",
        "Hyper": "co.zeit.hyper",
        "WezTerm": "com.github.wez.wezterm",
        "ghostty": "com.mitchellh.ghostty",
    ]

    // Last-resort process-tree walk: only worth activating if we land on one of
    // these. Anything else (a random launcher/wrapper app) isn't useful to jump to.
    private static let knownTerminalOrEditorBundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.microsoft.VSCode",
        "com.microsoft.VSCodeInsiders",
        "dev.warp.Warp-Stable",
        "co.zeit.hyper",
        "com.github.wez.wezterm",
        "io.alacritty",
        "net.kovidgoyal.kitty",
        "com.anthropic.claudefordesktop",
    ]

    static func reveal(pid: Int32) -> TerminalRevealResult {
        if DemoMode.isEnabled { return .notFound }
        let env = environment(for: pid)
        let ttyPath = tty(for: pid)

        // 1. Exact-tab matches for terminals with a stable session identity that
        //    survives a child process reallocating its own pty (nodemon, turbo, …),
        //    since env vars are inherited straight through fork/exec, tty is not.
        if let sessionID = env["ITERM_SESSION_ID"], let uuid = sessionID.split(separator: ":").last,
           isRunning(bundleID: "com.googlecode.iterm2"), revealInITerm(sessionID: String(uuid)) {
            return .focusedTab
        }
        if let ttyPath {
            if isRunning(bundleID: "com.apple.Terminal"), revealInTerminalApp(ttyPath: ttyPath) {
                return .focusedTab
            }
            if isRunning(bundleID: "com.googlecode.iterm2"), revealInITerm(ttyPath: ttyPath) {
                return .focusedTab
            }
        }

        // 2. Whatever GUI app's identity actually propagated down to this process —
        //    covers VS Code, Cursor, Claude Desktop, Xcode, etc. generically, without
        //    needing to hardcode every possible editor's bundle ID.
        if let bundleID = env["__CFBundleIdentifier"], let app = runningApp(bundleID: bundleID) {
            return .foundApp(name: app.localizedName ?? bundleID, bundleIdentifier: bundleID)
        }

        // 3. TERM_PROGRAM convention, in case __CFBundleIdentifier wasn't inherited.
        if let termProgram = env["TERM_PROGRAM"],
           let bundleID = termProgramBundleIDs[termProgram],
           let app = runningApp(bundleID: bundleID) {
            return .foundApp(name: app.localizedName ?? bundleID, bundleIdentifier: bundleID)
        }

        // 4. Last resort: walk the process tree (breaks if anything was reparented).
        if let app = ancestorRunningApp(startingFrom: pid),
           let bundleID = app.bundleIdentifier,
           knownTerminalOrEditorBundleIDs.contains(bundleID) {
            return .foundApp(name: app.localizedName ?? "the owning app", bundleIdentifier: bundleID)
        }

        return .notFound
    }

    static func activate(bundleIdentifier: String) {
        runningApp(bundleID: bundleIdentifier)?.activate(options: [.activateIgnoringOtherApps])
    }

    // MARK: - tty / environment lookup

    private static func tty(for pid: Int32) -> String? {
        let output = runProcess("/bin/ps", ["-o", "tty=", "-p", String(pid)])
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != "??" else { return nil }
        return "/dev/\(trimmed)"
    }

    /// Reads a handful of known identifying env vars for `pid` via `ps eww`.
    /// We deliberately don't attempt a full, faithful environ parse (ps concatenates
    /// COMMAND + env entries with plain spaces, and some values legitimately contain
    /// spaces, e.g. PATH segments) — we only need to detect specific well-known
    /// KEY=value tokens, which a targeted regex handles safely regardless of what
    /// else is on the line.
    private static func environment(for pid: Int32) -> [String: String] {
        let line = runProcess("/bin/ps", ["eww", "-p", String(pid)])
        let keys = ["__CFBundleIdentifier", "TERM_PROGRAM", "ITERM_SESSION_ID", "TERM_SESSION_ID", "VSCODE_PID", "CLAUDECODE"]
        var result: [String: String] = [:]
        for key in keys {
            if let value = extractEnvValue(key, from: line) {
                result[key] = value
            }
        }
        return result
    }

    private static func extractEnvValue(_ key: String, from raw: String) -> String? {
        let pattern = "(?:^|\\s)\(NSRegularExpression.escapedPattern(for: key))=(\\S+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(raw.startIndex..., in: raw)
        guard let match = regex.firstMatch(in: raw, range: range),
              let valueRange = Range(match.range(at: 1), in: raw) else { return nil }
        return String(raw[valueRange])
    }

    private static func isRunning(bundleID: String) -> Bool {
        runningApp(bundleID: bundleID) != nil
    }

    private static func runningApp(bundleID: String) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleID }
    }

    // MARK: - Terminal.app / iTerm2 via AppleScript (Automation permission, no Accessibility needed)

    private static func revealInTerminalApp(ttyPath: String) -> Bool {
        let script = """
        tell application "Terminal"
            repeat with w in windows
                repeat with t in tabs of w
                    if tty of t is "\(ttyPath)" then
                        set selected of t to true
                        set index of w to 1
                        activate
                        return true
                    end if
                end repeat
            end repeat
            return false
        end tell
        """
        return runAppleScript(script)
    }

    private static func revealInITerm(ttyPath: String) -> Bool {
        let script = """
        tell application "iTerm2"
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        if tty of s is "\(ttyPath)" then
                            select s
                            select t
                            select w
                            activate
                            return true
                        end if
                    end repeat
                end repeat
            end repeat
            return false
        end tell
        """
        return runAppleScript(script)
    }

    private static func revealInITerm(sessionID: String) -> Bool {
        let script = """
        tell application "iTerm2"
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        if id of s is "\(sessionID)" then
                            select s
                            select t
                            select w
                            activate
                            return true
                        end if
                    end repeat
                end repeat
            end repeat
            return false
        end tell
        """
        return runAppleScript(script)
    }

    private static func runAppleScript(_ source: String) -> Bool {
        guard let scriptObject = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        let result = scriptObject.executeAndReturnError(&error)
        if error != nil { return false }
        return result.booleanValue
    }

    // MARK: - Fallback: walk the process tree to the nearest running GUI app

    private static func ancestorRunningApp(startingFrom pid: Int32) -> NSRunningApplication? {
        let runningByPid = Dictionary(
            uniqueKeysWithValues: NSWorkspace.shared.runningApplications.map { ($0.processIdentifier, $0) }
        )
        var current = pid
        var hops = 0
        while current > 1 && hops < 32 {
            if let app = runningByPid[current] { return app }
            guard let parent = parentPid(of: current), parent != current else { break }
            current = parent
            hops += 1
        }
        return nil
    }

    private static func parentPid(of pid: Int32) -> Int32? {
        let output = runProcess("/bin/ps", ["-o", "ppid=", "-p", String(pid)])
        return Int32(output.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    @discardableResult
    private static func runProcess(_ path: String, _ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
