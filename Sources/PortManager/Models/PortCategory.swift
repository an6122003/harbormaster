import SwiftUI

enum PortCategory: String, CaseIterable, Sendable {
    case http
    case system
    case utility
    case external
    case error

    var label: String {
        rawValue.uppercased()
    }

    var color: Color {
        switch self {
        case .http: return .green
        case .system: return .blue
        case .utility: return .orange
        case .external: return .purple
        case .error: return .red
        }
    }
}

enum ProbeOutcome: Sendable, Hashable {
    case responded(status: Int)
    case timeout
    case refused
    case notProbed

    var isSuccessResponse: Bool {
        if case .responded = self { return true }
        return false
    }
}

enum PortStatus: String, Sendable {
    case listening = "Healthy"
    case noResponse = "Warning"
    case error = "Error"

    var color: Color {
        switch self {
        case .listening: return .green
        case .noResponse: return .orange
        case .error: return .red
        }
    }
}
