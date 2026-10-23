import Foundation

struct ProcessTreeNode: Identifiable, Sendable {
    let id: Int32
    let pid: Int32
    let name: String
    let command: String

    init(pid: Int32, name: String, command: String) {
        self.id = pid
        self.pid = pid
        self.name = name
        self.command = command
    }
}

enum ProcessTree {

    /// Walks from `pid` up to the root (pid 1), returning nodes ordered root-first.
    static func ancestry(of pid: Int32) -> [ProcessTreeNode] {
        if DemoMode.isEnabled { return DemoData.ancestry(of: pid) }
        var chain: [ProcessTreeNode] = []
        var current: Int32? = pid
        var hops = 0

        while let currentPid = current, currentPid > 0, hops < 64 {
            guard let info = processInfo(for: currentPid) else { break }
            chain.append(ProcessTreeNode(pid: currentPid, name: info.name, command: info.command))
            if currentPid == 1 { break }
            current = info.ppid
            hops += 1
        }

        return chain.reversed()
    }

    private static func processInfo(for pid: Int32) -> (name: String, command: String, ppid: Int32?)? {
        let output = runProcess("/bin/ps", ["-ww", "-o", "ppid=,comm=", "-p", String(pid)])
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let spaceIdx = trimmed.firstIndex(of: " ") else { return nil }
        let ppid = Int32(trimmed[trimmed.startIndex..<spaceIdx])
        let commPath = trimmed[trimmed.index(after: spaceIdx)...].trimmingCharacters(in: .whitespaces)
        let name = (commPath as NSString).lastPathComponent
        return (name: name, command: commPath, ppid: ppid)
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
