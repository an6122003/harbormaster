import Foundation

struct AppEvent: Identifiable {
    let id = UUID()
    let timestamp: Date
    let kind: Kind
    let message: String

    enum Kind {
        case kill
        case forceKill
        case alert
        case recovered
        case revealTerminal
        case info

        var systemImage: String {
            switch self {
            case .kill: return "xmark.circle"
            case .forceKill: return "bolt.circle"
            case .alert: return "exclamationmark.triangle"
            case .recovered: return "checkmark.circle"
            case .revealTerminal: return "terminal"
            case .info: return "info.circle"
            }
        }
    }
}
