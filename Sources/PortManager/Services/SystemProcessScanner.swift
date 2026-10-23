import Foundation

enum SystemProcessScanner {

    /// All processes visible to this user — the Task Manager view's data source.
    static func scan() -> [SystemProcessInfo] {
        if DemoMode.isEnabled { return DemoData.systemProcesses() }
        let output = runProcess("/bin/ps", ["-axo", "pid=,ppid=,%cpu=,rss=,user=,comm="])

        var results: [SystemProcessInfo] = []
        for line in output.split(separator: "\n") {
            let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 5, omittingEmptySubsequences: true)
            guard parts.count == 6,
                  let pid = Int32(parts[0]),
                  let ppid = Int32(parts[1]),
                  let cpu = Double(parts[2]),
                  let rss = Int(parts[3]) else { continue }
            let user = String(parts[4])
            let comm = parts[5].trimmingCharacters(in: .whitespaces)
            let name = humanizedName(from: (comm as NSString).lastPathComponent)
            let metrics = ProcessMetrics.metrics(forPID: pid, fallbackMemoryKB: rss)

            results.append(SystemProcessInfo(
                pid: pid, ppid: ppid, cpuPercent: cpu, memoryKB: metrics.memoryKB,
                threadCount: metrics.threadCount, user: user, name: name, command: comm
            ))
        }
        return results
    }

    /// Some system/XPC services report a reverse-DNS bundle identifier as their
    /// process name (e.g. "com.apple.Virtualization.VirtualMachine") instead of
    /// anything human-facing. We can't resolve exactly which app owns each one
    /// the way Activity Monitor does (that needs private "responsible process"
    /// APIs), but showing "Virtual Machine" beats a raw identifier string.
    private static func humanizedName(from raw: String) -> String {
        guard raw.contains("."), !raw.contains(" "),
              raw.range(of: "^[A-Za-z0-9]+(\\.[A-Za-z0-9_-]+)+$", options: .regularExpression) != nil else {
            return raw
        }
        let lastComponent = raw.split(separator: ".").last.map(String.init) ?? raw
        return spaceCamelCase(lastComponent)
    }

    private static func spaceCamelCase(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "(?<=[a-z0-9])(?=[A-Z])") else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: " ")
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
