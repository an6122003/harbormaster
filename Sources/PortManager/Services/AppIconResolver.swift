import AppKit

/// Resolves the real, installed app icon for a process name when one genuinely
/// exists on this Mac (Discord, Google Drive, Docker Desktop, VS Code, …) — the
/// same icon Finder/Activity Monitor would show, since we're just asking
/// LaunchServices for the icon of an app already on this machine.
@MainActor
enum AppIconResolver {
    private static let processToBundleID: [String: String] = [
        "Discord Helper": "com.hnc.Discord",
        "Discord Helper (Renderer)": "com.hnc.Discord",
        "Discord Helper (GPU)": "com.hnc.Discord",
        "Discord Helper (Plugin)": "com.hnc.Discord",
        "Discord": "com.hnc.Discord",
        "Google Drive": "com.google.GoogleDrive",
        "Code Helper": "com.microsoft.VSCode",
        "Code Helper (Renderer)": "com.microsoft.VSCode",
        "Code Helper (Plugin)": "com.microsoft.VSCode",
        "Code Helper (GPU)": "com.microsoft.VSCode",
        "com.docker.backend": "com.docker.docker",
        "com.docker.driver.amd64-linux": "com.docker.docker",
        "Docker": "com.docker.docker",
        "com.apple.controlcenter": "com.apple.controlcenter",
        "ControlCenter": "com.apple.controlcenter",
        "Spotify": "com.spotify.client",
        "Slack": "com.tinyspeck.slackmacgap",
        "Postman": "com.postmanlabs.mac",
        "TablePlus": "com.tinyapp.TablePlus",
    ]

    private static var cache: [String: NSImage?] = [:]

    static func icon(forProcessName name: String) -> NSImage? {
        if let cached = cache[name] { return cached }
        let resolved = resolve(name)
        cache[name] = resolved
        return resolved
    }

    private static func resolve(_ name: String) -> NSImage? {
        guard let bundleID = processToBundleID[name],
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
