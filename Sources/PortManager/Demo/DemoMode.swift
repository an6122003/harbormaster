import Foundation

/// `--demo` swaps every system probe for fictional sample data and turns
/// stop/reveal into no-ops, so the app can be shown, screenshotted or developed
/// without exposing (or ever touching) the processes on the real machine.
///
/// `--snapshot <dir>` implies `--demo`: it walks through the main screens, saves
/// a PNG of each into `<dir>`, then quits. The README screenshots come from this.
enum DemoMode {
    static let isEnabled: Bool = {
        let arguments = CommandLine.arguments
        return arguments.contains("--demo")
            || arguments.contains("--snapshot")
            || ProcessInfo.processInfo.environment["PORTMANAGER_DEMO"] == "1"
    }()

    static let snapshotDirectory: URL? = {
        let arguments = CommandLine.arguments
        guard let flag = arguments.firstIndex(of: "--snapshot"), flag + 1 < arguments.count else { return nil }
        return URL(fileURLWithPath: arguments[flag + 1], isDirectory: true)
    }()
}
