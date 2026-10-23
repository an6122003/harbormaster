import Darwin
import Foundation

enum ProcessKiller {

    @discardableResult
    static func send(pid: Int32, force: Bool) -> Bool {
        // Demo PIDs are fiction and could collide with real ones — never signal anything.
        if DemoMode.isEnabled { return true }
        guard pid != ProcessInfo.processInfo.processIdentifier else { return false }
        let signal: Int32 = force ? SIGKILL : SIGTERM
        return kill(pid, signal) == 0
    }
}
