import Foundation

private let knownSystemProcessNames: Set<String> = [
    "ControlCenter", "rapportd", "sharingd", "identityservicesd", "AirPlayXPCHelper",
    "launchd", "coreaudiod", "distnoted", "cloudd", "WindowServer", "mDNSResponder",
    "bluetoothd", "syslogd", "systemstats", "apsd", "biomed", "netbiosd", "usernoted",
]

struct PortInfo: Identifiable, Hashable, Sendable {
    var id: String { "\(pid)-\(port)" }

    let port: Int
    let pid: Int32
    let processName: String
    var command: String = ""
    var user: String = ""
    var workingDirectory: String = ""
    var startedAtRaw: String = ""
    var uptimeRaw: String = ""
    var boundAddress: String = ""
    var connectionsCount: Int = 0
    var memoryKB: Int = 0
    var nodeEnv: String = ""
    var runtimeVersion: String = ""

    var reachable: Bool = false
    var httpStatus: Int? = nil
    var title: String = ""
    var server: String = ""
    var contentType: String = ""
    var headers: [String: String] = [:]
    var probeOutcome: ProbeOutcome = .notProbed
    var latencyMS: Double? = nil

    var isExternallyBound: Bool {
        boundAddress == "*" || boundAddress == "0.0.0.0"
    }

    var status: PortStatus {
        switch probeOutcome {
        case .responded: return .listening
        case .timeout: return .noResponse
        case .refused: return .error
        case .notProbed: return .noResponse
        }
    }

    var category: PortCategory {
        if knownSystemProcessNames.contains(processName) { return .system }
        if case .refused = probeOutcome { return .error }
        if isExternallyBound { return .external }
        if probeOutcome.isSuccessResponse { return .http }
        return .utility
    }

    var previewURL: URL? {
        URL(string: "http://127.0.0.1:\(port)/")
    }

    func networkURL(lanIP: String?) -> URL? {
        guard let lanIP, isExternallyBound else { return nil }
        return URL(string: "http://\(lanIP):\(port)/")
    }

    var detectedLabel: String {
        if !title.isEmpty { return title }
        if reachable { return "HTTP \(httpStatus ?? 0)" }
        return "No HTTP response"
    }

    var protocolLabel: String {
        reachable ? "HTTP" : "TCP"
    }

    var memoryLabel: String { MemoryFormat.label(kb: memoryKB) }

    var statusCodeLabel: String {
        guard let httpStatus else { return "—" }
        return "\(httpStatus) \(HTTPStatusText.reason(for: httpStatus))"
    }

    var latencyLabel: String {
        guard let latencyMS else { return "—" }
        return latencyMS < 1 ? "<1 ms" : "\(Int(latencyMS.rounded())) ms"
    }
}

