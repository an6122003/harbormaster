import Foundation

struct AppRevealCandidate: Identifiable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
}

@MainActor
final class PortListViewModel: ObservableObject {
    @Published var ports: [PortInfo] = []
    @Published var isLoading = false
    @Published var lastUpdated: Date?
    @Published var searchText: String = ""
    @Published var autoRefresh: Bool = true
    @Published var revealMessage: String?
    @Published var appRevealCandidate: AppRevealCandidate?

    @Published var sidebarSection: SidebarSection = .overview
    @Published var portsFilter: PortsFilter = .all
    @Published var selectedPortIDs: Set<PortInfo.ID> = []
    @Published var mapViewMode: MapViewMode = .networkMap
    @Published var events: [AppEvent] = []
    @Published var lanIP: String?
    @Published private(set) var memoryHistory: [PortInfo.ID: [Int]] = [:]
    @Published private(set) var portlessDevProcesses: [DevProcessInfo] = []
    /// Lets the demo snapshot runner pick which detail tab to show; unused in normal use.
    @Published var requestedDetailTab: DetailTab?

    private var refreshLoop: Task<Void, Never>?
    private var knownAlertPortIDs: Set<PortInfo.ID> = []
    private var hasScannedOnce = false

    init() {
        if DemoMode.isEnabled {
            events = DemoData.events()
        }
    }

    /// Convenience single-selection accessor for call sites (graph nodes, Alerts/Processes
    /// navigation) that only ever want to select exactly one port at a time. Reading it
    /// back returns nil while a multi-selection is active in the list.
    var selectedPortID: PortInfo.ID? {
        get { selectedPortIDs.count == 1 ? selectedPortIDs.first : nil }
        set { selectedPortIDs = newValue.map { [$0] } ?? [] }
    }

    var selectedPort: PortInfo? {
        guard let selectedPortID else { return nil }
        return ports.first { $0.id == selectedPortID }
    }

    var selectedPorts: [PortInfo] {
        ports.filter { selectedPortIDs.contains($0.id) }
    }

    var hasBulkSelection: Bool { selectedPortIDs.count > 1 }

    var filteredPorts: [PortInfo] {
        var result = ports
        switch portsFilter {
        case .all:
            break
        case .listening:
            result = result.filter { $0.status == .listening }
        case .external:
            result = result.filter { $0.isExternallyBound }
        }
        guard !searchText.isEmpty else { return result }
        let query = searchText.lowercased()
        return result.filter {
            String($0.port).contains(query)
                || $0.processName.lowercased().contains(query)
                || $0.command.lowercased().contains(query)
                || $0.title.lowercased().contains(query)
        }
    }

    var listeningCount: Int { ports.filter { $0.status == .listening }.count }
    var externalCount: Int { ports.filter { $0.isExternallyBound }.count }
    var noResponseCount: Int { ports.filter { $0.status == .noResponse }.count }
    var errorCount: Int { ports.filter { $0.status == .error }.count }
    var alertPorts: [PortInfo] { ports.filter { $0.status != .listening } }

    func refresh() async {
        isLoading = true
        let newPorts = await PortScanner.scan()
        detectAlertTransitions(to: newPorts)
        recordMemoryHistory(for: newPorts)
        ports = newPorts
        lastUpdated = Date()
        isLoading = false

        if lanIP == nil {
            lanIP = await Task.detached { NetworkInfo.lanIPAddress() }.value
        }

        let portedPIDs = Set(newPorts.map(\.pid))
        portlessDevProcesses = await Task.detached { DevProcessScanner.scan(excludingPIDs: portedPIDs) }.value
    }

    private func recordMemoryHistory(for newPorts: [PortInfo]) {
        let currentIDs = Set(newPorts.map(\.id))
        for port in newPorts {
            var history = memoryHistory[port.id] ?? (DemoMode.isEnabled ? DemoData.memoryHistory(for: port) : [])
            history.append(port.memoryKB)
            if history.count > 24 { history.removeFirst(history.count - 24) }
            memoryHistory[port.id] = history
        }
        memoryHistory = memoryHistory.filter { currentIDs.contains($0.key) }
    }

    /// Logs a port's move into (or out of) an unhealthy state. The very first scan only
    /// establishes the baseline: ports that were already unhealthy when the app launched
    /// aren't "transitions", and reporting them as such would fill History with noise on
    /// every launch.
    private func detectAlertTransitions(to newPorts: [PortInfo]) {
        for port in newPorts {
            let isAlerting = port.status != .listening
            let wasAlerting = knownAlertPortIDs.contains(port.id)
            if isAlerting, !wasAlerting {
                knownAlertPortIDs.insert(port.id)
                if hasScannedOnce {
                    logEvent(.alert, "Port \(port.port) (\(port.processName)) went to \(port.status.rawValue)")
                }
            } else if !isAlerting, wasAlerting {
                knownAlertPortIDs.remove(port.id)
                logEvent(.recovered, "Port \(port.port) (\(port.processName)) is responding again")
            }
        }
        knownAlertPortIDs.formIntersection(Set(newPorts.map(\.id)))
        hasScannedOnce = true
    }

    func startAutoRefresh(interval: TimeInterval = 4) {
        guard refreshLoop == nil else { return }
        refreshLoop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard let self, self.autoRefresh else { continue }
                await self.refresh()
            }
        }
    }

    func stopAutoRefresh() {
        refreshLoop?.cancel()
        refreshLoop = nil
    }

    func kill(_ info: PortInfo, force: Bool = false) {
        ProcessKiller.send(pid: info.pid, force: force)
        logEvent(force ? .forceKill : .kill, "\(force ? "Force quit" : "Stopped") \(info.processName) (PID \(info.pid)) on port \(info.port)")
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await refresh()
        }
    }

    func kill(_ info: DevProcessInfo, force: Bool = false) {
        ProcessKiller.send(pid: info.pid, force: force)
        logEvent(force ? .forceKill : .kill, "\(force ? "Force quit" : "Stopped") \(info.name) (PID \(info.pid))")
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await refresh()
        }
    }

    func bulkStop(_ infos: [PortInfo], force: Bool = false) {
        for info in infos {
            ProcessKiller.send(pid: info.pid, force: force)
        }
        logEvent(
            force ? .forceKill : .kill,
            "\(force ? "Force quit" : "Stopped") \(infos.count) processes: ports \(infos.map { String($0.port) }.joined(separator: ", "))"
        )
        selectedPortIDs.removeAll()
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await refresh()
        }
    }

    func clearSelection() {
        selectedPortIDs.removeAll()
    }

    func revealTerminal(for info: PortInfo) {
        Task {
            let pid = info.pid
            let result = await Task.detached { TerminalLocator.reveal(pid: pid) }.value
            switch result {
            case .focusedTab:
                revealMessage = nil
                appRevealCandidate = nil
                logEvent(.revealTerminal, "Focused terminal tab for port \(info.port)")
            case .foundApp(let name, let bundleID):
                appRevealCandidate = AppRevealCandidate(name: name, bundleIdentifier: bundleID)
            case .notFound:
                revealMessage = "No open Terminal/iTerm2 tab matches PID \(info.pid) on port \(info.port). It may run under a tool that allocates its own pseudo-terminal (nodemon, concurrently, turbo, etc.), share a tab with other processes, or run outside a supported terminal."
            }
        }
    }

    func confirmAppReveal() {
        guard let candidate = appRevealCandidate else { return }
        TerminalLocator.activate(bundleIdentifier: candidate.bundleIdentifier)
        logEvent(.revealTerminal, "Brought \(candidate.name) to the front for the selected process")
        appRevealCandidate = nil
    }

    func logEvent(_ kind: AppEvent.Kind, _ message: String) {
        events.insert(AppEvent(timestamp: Date(), kind: kind, message: message), at: 0)
        if events.count > 200 {
            events.removeLast(events.count - 200)
        }
    }
}
