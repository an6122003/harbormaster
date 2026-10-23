import Foundation

enum NetworkInfo {

    static func lanIPAddress() -> String? {
        if DemoMode.isEnabled { return DemoData.lanIP }
        guard let interface = defaultRouteInterface() else { return nil }
        let ip = runProcess("/usr/sbin/ipconfig", ["getifaddr", interface]).trimmingCharacters(in: .whitespacesAndNewlines)
        return ip.isEmpty ? nil : ip
    }

    private static func defaultRouteInterface() -> String? {
        let output = runProcess("/sbin/route", ["-n", "get", "default"])
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("interface:") {
                return trimmed.replacingOccurrences(of: "interface:", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
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
