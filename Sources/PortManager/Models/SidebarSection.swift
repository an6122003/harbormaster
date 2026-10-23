import Foundation

enum SidebarSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case ports = "Ports"
    case processes = "Processes"
    case taskManager = "Task Manager"
    case alerts = "Alerts"
    case history = "History"
    case settings = "Settings"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .overview: return "point.3.connected.trianglepath.dotted"
        case .ports: return "square.grid.2x2"
        case .processes: return "cpu"
        case .taskManager: return "speedometer"
        case .alerts: return "bell.badge"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        }
    }
}

enum PortsFilter: String, CaseIterable, Identifiable {
    case all = "All Ports"
    case listening = "Listening"
    case external = "External"

    var id: String { rawValue }
}

enum MapViewMode: String, CaseIterable, Identifiable {
    case networkMap = "Network Map"
    case processTree = "Process Tree"
    case connectionFlow = "Connection Flow"

    var id: String { rawValue }
}
