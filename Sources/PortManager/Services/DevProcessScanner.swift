import Foundation

enum DevProcessScanner {
    private static let nameHints: [String] = [
        "node", "next-server", "npm", "yarn", "pnpm", "python", "ruby", "deno",
        "bun", "java", "webpack", "vite", "turbopack", "ts-node", "nodemon",
    ]
    private static let minimumMemoryKB = 30_000 // ~30 MB — filters out noise, keeps anything worth surfacing
    private static let maxResults = 15

    /// Best-effort scan for dev-workflow-shaped processes that hold no listening
    /// socket right now (so PortScanner's lsof-based pass can't find them).
    /// `excludingPIDs` should be every pid already represented by a real port.
    static func scan(excludingPIDs: Set<Int32>) -> [DevProcessInfo] {
        if DemoMode.isEnabled { return DemoData.portlessDevProcesses }
        let output = runProcess("/bin/ps", ["-ax", "-o", "pid=,ppid=,rss=,user=,comm="])

        var results: [DevProcessInfo] = []
        for line in output.split(separator: "\n") {
            let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 4, omittingEmptySubsequences: true)
            guard parts.count == 5,
                  let pid = Int32(parts[0]), !excludingPIDs.contains(pid),
                  let ppid = Int32(parts[1]),
                  let rss = Int(parts[2]) else { continue }
            let user = String(parts[3])
            let comm = parts[4].trimmingCharacters(in: .whitespaces)
            let commandName = (comm as NSString).lastPathComponent

            guard rss >= minimumMemoryKB else { continue }
            guard nameHints.contains(where: { comm.lowercased().contains($0) }) else { continue }

            let memoryKB = ProcessMetrics.metrics(forPID: pid, fallbackMemoryKB: rss).memoryKB
            results.append(DevProcessInfo(pid: pid, ppid: ppid, name: commandName, command: comm, user: user, memoryKB: memoryKB))
        }

        return Array(results.sorted { $0.memoryKB > $1.memoryKB }.prefix(maxResults))
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
