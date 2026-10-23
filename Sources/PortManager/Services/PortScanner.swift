import Foundation

enum PortScanner {

    static func scan() async -> [PortInfo] {
        if DemoMode.isEnabled { return DemoData.ports() }
        let raw = runLsof()
        let (bare, connectionCounts) = parseLsof(raw)
        guard !bare.isEmpty else { return [] }

        let pids = Set(bare.map { $0.pid })
        let commands = processCommands(pids: pids)
        let meta = processMeta(pids: pids)
        let cwds = workingDirectories(pids: pids)
        let nodeEnvs = nodeEnvValues(pids: pids)

        let enriched = bare.map { info -> PortInfo in
            var copy = info
            copy.command = commands[info.pid] ?? ""
            copy.user = meta[info.pid]?.user ?? ""
            if let seconds = meta[info.pid]?.elapsedSeconds {
                copy.uptimeRaw = formatUptime(seconds)
                copy.startedAtRaw = startedAtFormatter.string(from: Date().addingTimeInterval(-seconds))
            }
            copy.workingDirectory = cwds[info.pid] ?? ""
            copy.connectionsCount = connectionCounts[info.port] ?? 0
            // ps -o rss= is not what Activity Monitor shows — fall back to it only
            // when the more accurate libproc footprint reading is unavailable
            // (cross-user processes we don't have permission to introspect).
            copy.memoryKB = ProcessMetrics.metrics(forPID: info.pid, fallbackMemoryKB: meta[info.pid]?.memoryKB ?? 0).memoryKB
            copy.nodeEnv = nodeEnvs[info.pid] ?? ""
            copy.runtimeVersion = runtimeVersion(forCommand: copy.command)
            return copy
        }

        let probed = await withTaskGroup(of: PortInfo.self) { group in
            for info in enriched {
                group.addTask { await probeHTTP(info) }
            }
            var results: [PortInfo] = []
            results.reserveCapacity(enriched.count)
            for await result in group {
                results.append(result)
            }
            return results
        }

        return probed.sorted { $0.port < $1.port }
    }

    // MARK: - lsof (listening sockets + established connection counts, one call)

    private static func runLsof() -> String {
        runProcess("/usr/sbin/lsof", ["-iTCP", "-n", "-P", "-F", "pcn"])
    }

    private static func parseLsof(_ raw: String) -> ([PortInfo], [Int: Int]) {
        var currentPid: Int32 = 0
        var currentCommand = ""
        var seenKeys = Set<String>()
        var results: [PortInfo] = []
        var connectionCounts: [Int: Int] = [:]

        for line in raw.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let tag = line.first else { continue }
            let value = String(line.dropFirst())

            switch tag {
            case "p":
                currentPid = Int32(value) ?? 0
            case "c":
                currentCommand = value
            case "n":
                if let arrowRange = value.range(of: "->") {
                    // Established (or other non-listening) connection: "local->remote"
                    let local = value[value.startIndex..<arrowRange.lowerBound]
                    guard let colonIdx = local.lastIndex(of: ":"), let port = Int(local[local.index(after: colonIdx)...]) else { continue }
                    connectionCounts[port, default: 0] += 1
                } else {
                    guard let colonIdx = value.lastIndex(of: ":") else { continue }
                    let addressPart = value[value.startIndex..<colonIdx]
                    let portStr = value[value.index(after: colonIdx)...]
                    guard let port = Int(portStr) else { continue }
                    let key = "\(currentPid):\(port)"
                    guard !seenKeys.contains(key) else { continue }
                    seenKeys.insert(key)
                    var info = PortInfo(port: port, pid: currentPid, processName: currentCommand)
                    info.boundAddress = String(addressPart)
                    results.append(info)
                }
            default:
                break
            }
        }
        return (results, connectionCounts)
    }

    // MARK: - ps (full command line for each pid, one call for all)

    private static func processCommands(pids: Set<Int32>) -> [Int32: String] {
        guard !pids.isEmpty else { return [:] }
        let output = runProcess("/bin/ps", ["-ww", "-ax", "-o", "pid=,command="])

        var map: [Int32: String] = [:]
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let spaceIdx = trimmed.firstIndex(of: " ") else { continue }
            guard let pid = Int32(trimmed[trimmed.startIndex..<spaceIdx]), pids.contains(pid) else { continue }
            map[pid] = trimmed[trimmed.index(after: spaceIdx)...].trimmingCharacters(in: .whitespaces)
        }
        return map
    }

    private struct ProcessMeta {
        let user: String
        let elapsedSeconds: TimeInterval?
        let memoryKB: Int
    }

    private static func processMeta(pids: Set<Int32>) -> [Int32: ProcessMeta] {
        guard !pids.isEmpty else { return [:] }
        let output = runProcess("/bin/ps", ["-ax", "-o", "pid=,user=,etime=,rss="])

        var map: [Int32: ProcessMeta] = [:]
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            guard parts.count >= 4, let pid = Int32(parts[0]), pids.contains(pid) else { continue }
            let user = String(parts[1])
            let elapsed = parseElapsedSeconds(String(parts[2]))
            let memoryKB = Int(parts[3]) ?? 0
            map[pid] = ProcessMeta(user: user, elapsedSeconds: elapsed, memoryKB: memoryKB)
        }
        return map
    }

    private static func parseElapsedSeconds(_ etime: String) -> TimeInterval? {
        var days = 0
        var rest = Substring(etime)
        if let dashIdx = etime.firstIndex(of: "-") {
            days = Int(etime[etime.startIndex..<dashIdx]) ?? 0
            rest = etime[etime.index(after: dashIdx)...]
        }
        let parts = rest.split(separator: ":").compactMap { Int($0) }
        guard !parts.isEmpty else { return nil }
        var seconds = 0
        var multiplier = 1
        for part in parts.reversed() {
            seconds += part * multiplier
            multiplier *= 60
        }
        return TimeInterval(days * 86400 + seconds)
    }

    private static func formatUptime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if days > 0 { return "\(days)d \(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h \(minutes)m \(secs)s" }
        if minutes > 0 { return "\(minutes)m \(secs)s" }
        return "\(secs)s"
    }

    private static let startedAtFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    // MARK: - lsof (working directory for each pid, one call for all)

    private static func workingDirectories(pids: Set<Int32>) -> [Int32: String] {
        guard !pids.isEmpty else { return [:] }
        let pidList = pids.map(String.init).joined(separator: ",")
        let output = runProcess("/usr/sbin/lsof", ["-a", "-p", pidList, "-d", "cwd", "-F", "pn"])

        var map: [Int32: String] = [:]
        var currentPid: Int32 = 0
        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let tag = line.first else { continue }
            let value = String(line.dropFirst())
            switch tag {
            case "p":
                currentPid = Int32(value) ?? 0
            case "n":
                map[currentPid] = value
            default:
                break
            }
        }
        return map
    }

    // MARK: - NODE_ENV (one broad ps call, filtered to our pids)

    private static func nodeEnvValues(pids: Set<Int32>) -> [Int32: String] {
        guard !pids.isEmpty else { return [:] }
        let output = runProcess("/bin/ps", ["eww", "-ax"])

        var map: [Int32: String] = [:]
        for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let spaceIdx = trimmed.firstIndex(of: " ") else { continue }
            guard let pid = Int32(trimmed[trimmed.startIndex..<spaceIdx]), pids.contains(pid) else { continue }
            if let value = extractEnvValue("NODE_ENV", from: String(trimmed)) {
                map[pid] = "NODE_ENV=\(value)"
            }
        }
        return map
    }

    private static func extractEnvValue(_ key: String, from raw: String) -> String? {
        let pattern = "(?:^|\\s)\(NSRegularExpression.escapedPattern(for: key))=(\\S+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(raw.startIndex..., in: raw)
        guard let match = regex.firstMatch(in: raw, range: range),
              let valueRange = Range(match.range(at: 1), in: raw) else { return nil }
        return String(raw[valueRange])
    }

    // MARK: - Runtime version (node --version, python3 --version, …), cached per executable

    private static let knownVersionedRuntimes: Set<String> = ["node", "python", "python3", "ruby", "deno", "bun", "php"]
    private static var versionCache: [String: String] = [:]

    private static func runtimeVersion(forCommand command: String) -> String {
        guard let executablePath = command.split(separator: " ", maxSplits: 1).first.map(String.init),
              knownVersionedRuntimes.contains((executablePath as NSString).lastPathComponent) else {
            return ""
        }
        if let cached = versionCache[executablePath] { return cached }
        let output = runProcess(executablePath, ["--version"]).trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLine = output.split(separator: "\n").first.map(String.init) ?? ""
        versionCache[executablePath] = firstLine
        return firstLine
    }

    // MARK: - HTTP probe

    private static func probeHTTP(_ entry: PortInfo) async -> PortInfo {
        var result = entry
        guard let url = URL(string: "http://127.0.0.1:\(entry.port)/") else { return result }

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 0.9
        config.timeoutIntervalForResource = 1.4
        let session = URLSession(configuration: config)

        let start = Date()
        do {
            let (data, response) = try await session.data(from: url)
            result.latencyMS = Date().timeIntervalSince(start) * 1000
            result.reachable = true
            if let http = response as? HTTPURLResponse {
                result.httpStatus = http.statusCode
                result.contentType = http.value(forHTTPHeaderField: "Content-Type") ?? ""
                result.server = http.value(forHTTPHeaderField: "Server") ?? ""
                var headers: [String: String] = [:]
                for (key, value) in http.allHeaderFields {
                    headers["\(key)"] = "\(value)"
                }
                result.headers = headers
                result.probeOutcome = .responded(status: http.statusCode)
            }
            if result.contentType.lowercased().contains("text/html"),
               let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) {
                result.title = extractTitle(from: text)
            }
        } catch {
            result.reachable = false
            let nsError = error as NSError
            switch nsError.code {
            case NSURLErrorTimedOut:
                result.probeOutcome = .timeout
            case NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost:
                result.probeOutcome = .refused
            default:
                result.probeOutcome = .timeout
            }
        }
        return result
    }

    private static func extractTitle(from html: String) -> String {
        guard let range = html.range(of: "<title[^>]*>([^<]*)</title>", options: [.regularExpression, .caseInsensitive]) else {
            return ""
        }
        var tag = String(html[range])
        tag = tag.replacingOccurrences(of: "<title[^>]*>", with: "", options: [.regularExpression, .caseInsensitive])
        tag = tag.replacingOccurrences(of: "</title>", with: "", options: [.regularExpression, .caseInsensitive])
        return tag.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Process helper

    @discardableResult
    private static func runProcess(_ path: String, _ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            return ""
        }

        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
