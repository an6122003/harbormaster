import Foundation

/// A process that looks like part of a dev workflow (node, next-server, python, …)
/// but currently holds no listening socket, so PortScanner would never surface it —
/// e.g. a dev server mid-restart, or a worker process left running after its
/// listener died. Surfaced separately so heavy-but-portless processes aren't invisible.
struct DevProcessInfo: Identifiable, Hashable, Sendable {
    var id: Int32 { pid }
    let pid: Int32
    let ppid: Int32
    let name: String
    let command: String
    let user: String
    let memoryKB: Int

    var memoryLabel: String { MemoryFormat.label(kb: memoryKB) }
}
