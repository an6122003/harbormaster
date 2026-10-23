import Foundation

enum MemoryFormat {
    /// Human-readable size for a kilobyte count — GB / MB / KB, whichever reads best.
    static func label(kb: Int) -> String {
        guard kb > 0 else { return "—" }
        if kb >= 1024 * 1024 { return String(format: "%.2f GB", Double(kb) / (1024 * 1024)) }
        if kb >= 1024 { return String(format: "%.1f MB", Double(kb) / 1024) }
        return "\(kb) KB"
    }
}
