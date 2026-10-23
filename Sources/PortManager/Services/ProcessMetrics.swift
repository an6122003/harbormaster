import Darwin
import Foundation

/// Accurate per-process memory + thread count via libproc — the same underlying
/// mechanism Activity Monitor uses (`phys_footprint`, not raw RSS). RSS and
/// footprint can differ enormously for processes with lots of compressed/shared
/// memory (VMs, browsers): a raw `ps -o rss=` reading is not "what Activity
/// Monitor shows," it's a different, smaller number.
///
/// `proc_pid_rusage`/`proc_pidinfo(PROC_PIDTASKINFO)` only succeed for processes
/// owned by the current user (or when running as root) — cross-user processes
/// (WindowServer, kernel daemons, …) fail here, so callers must supply a
/// `fallbackMemoryKB` (from `ps -o rss=`, which *can* read other users' basic
/// stats) to fall back on.
enum ProcessMetrics {
    struct Metrics {
        let memoryKB: Int
        let threadCount: Int?
    }

    static func metrics(forPID pid: Int32, fallbackMemoryKB: Int) -> Metrics {
        var footprintKB: Int?
        var rusage = rusage_info_v4()
        let rusageResult = withUnsafeMutablePointer(to: &rusage) { ptr -> Int32 in
            ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { typedPtr in
                proc_pid_rusage(pid, RUSAGE_INFO_V4, typedPtr)
            }
        }
        if rusageResult == 0 {
            footprintKB = Int(rusage.ri_phys_footprint / 1024)
        }

        var threadCount: Int?
        var taskInfo = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        let taskResult = withUnsafeMutablePointer(to: &taskInfo) { ptr -> Int32 in
            proc_pidinfo(pid, PROC_PIDTASKINFO, 0, ptr, size)
        }
        if taskResult > 0 {
            threadCount = Int(taskInfo.pti_threadnum)
        }

        return Metrics(memoryKB: footprintKB ?? fallbackMemoryKB, threadCount: threadCount)
    }
}
