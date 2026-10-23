import Foundation

struct SystemProcessInfo: Identifiable, Hashable, Sendable {
    var id: Int32 { pid }
    let pid: Int32
    let ppid: Int32
    let cpuPercent: Double
    let memoryKB: Int
    let threadCount: Int?
    let user: String
    let name: String
    let command: String

    var memoryLabel: String { MemoryFormat.label(kb: memoryKB) }

    var threadLabel: String {
        threadCount.map(String.init) ?? "—"
    }

    var cpuLabel: String {
        String(format: "%.1f%%", cpuPercent)
    }
}
