import Foundation

struct ConnectionInfo: Identifiable, Sendable, Hashable {
    var id: String { "\(localAddress)-\(remoteAddress)-\(state)" }
    let localAddress: String
    let remoteAddress: String
    let state: String
}

enum ConnectionInspector {

    static func connections(forPort port: Int) -> [ConnectionInfo] {
        if DemoMode.isEnabled { return DemoData.connections(forPort: port) }
        let output = runProcess("/usr/sbin/lsof", ["-iTCP:\(port)", "-n", "-P"])
        var results: [ConnectionInfo] = []

        for line in output.split(separator: "\n").dropFirst() {
            let tokens = line.split(separator: " ", omittingEmptySubsequences: true)
            guard let addrToken = tokens.first(where: { $0.contains("->") }) else { continue }
            guard let arrow = addrToken.range(of: "->") else { continue }
            let local = String(addrToken[addrToken.startIndex..<arrow.lowerBound])
            let remote = String(addrToken[arrow.upperBound...])

            var state = "UNKNOWN"
            if let last = tokens.last, last.hasPrefix("("), last.hasSuffix(")") {
                state = String(last.dropFirst().dropLast())
            }
            results.append(ConnectionInfo(localAddress: local, remoteAddress: remote, state: state))
        }
        return results
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
