import SwiftUI

private enum SortField: String, CaseIterable {
    case name = "Process"
    case pid = "PID"
    case cpu = "CPU"
    case memory = "Memory"
    case threads = "Threads"
    case user = "User"
}

struct TaskManagerView: View {
    @EnvironmentObject var viewModel: PortListViewModel

    @State private var processes: [SystemProcessInfo] = []
    @State private var searchText = ""
    @State private var sortField: SortField = .memory
    @State private var sortAscending = false
    @State private var pendingKill: SystemProcessInfo?
    @State private var pendingForceKill: SystemProcessInfo?
    @State private var isLoading = false

    private var filteredAndSorted: [SystemProcessInfo] {
        var result = processes
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query)
                    || $0.command.lowercased().contains(query)
                    || String($0.pid).contains(query)
            }
        }
        result.sort { a, b in
            let ascending: Bool
            switch sortField {
            case .name: ascending = a.name.lowercased() < b.name.lowercased()
            case .pid: ascending = a.pid < b.pid
            case .cpu: ascending = a.cpuPercent < b.cpuPercent
            case .memory: ascending = a.memoryKB < b.memoryKB
            case .threads: ascending = (a.threadCount ?? -1) < (b.threadCount ?? -1)
            case .user: ascending = a.user.lowercased() < b.user.lowercased()
            }
            return sortAscending ? ascending : !ascending
        }
        return result
    }

    private var totalMemoryLabel: String {
        let totalKB = processes.reduce(0) { $0 + $1.memoryKB }
        return String(format: "%.1f GB", Double(totalKB) / (1024 * 1024))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            searchRow
            columnHeader
            Divider()
            list
        }
        .task {
            await refreshLoop()
        }
        .alert("Stop \(pendingKill?.name ?? "")?", isPresented: Binding(get: { pendingKill != nil }, set: { if !$0 { pendingKill = nil } })) {
            Button("Cancel", role: .cancel) { pendingKill = nil }
            Button("Stop", role: .destructive) {
                if let process = pendingKill { stop(process, force: false) }
                pendingKill = nil
            }
        } message: {
            Text(verbatim: "Sends SIGTERM to PID \(pendingKill?.pid ?? 0).")
        }
        .alert("Force Quit \(pendingForceKill?.name ?? "")?", isPresented: Binding(get: { pendingForceKill != nil }, set: { if !$0 { pendingForceKill = nil } })) {
            Button("Cancel", role: .cancel) { pendingForceKill = nil }
            Button("Force Quit", role: .destructive) {
                if let process = pendingForceKill { stop(process, force: true) }
                pendingForceKill = nil
            }
        } message: {
            Text(verbatim: "Sends SIGKILL to PID \(pendingForceKill?.pid ?? 0). Unsaved work may be lost.")
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Task Manager").font(.title2.bold())
                Text(verbatim: "\(processes.count) processes · \(totalMemoryLabel) resident memory")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isLoading {
                ProgressView().controlSize(.small)
            }
        }
        .padding(20)
    }

    private var searchRow: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.caption)
            TextField("Filter by name, command, or PID...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.05)))
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }

    private var columnHeader: some View {
        HStack {
            sortButton(.name).frame(width: 220, alignment: .leading)
            sortButton(.pid).frame(width: 70, alignment: .leading)
            sortButton(.cpu).frame(width: 70, alignment: .leading)
            sortButton(.memory).frame(width: 90, alignment: .leading)
            sortButton(.threads).frame(width: 70, alignment: .leading)
            sortButton(.user).frame(maxWidth: .infinity, alignment: .leading)
            Text("").frame(width: 40)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }

    private func sortButton(_ field: SortField) -> some View {
        Button {
            if sortField == field {
                sortAscending.toggle()
            } else {
                sortField = field
                sortAscending = false
            }
        } label: {
            HStack(spacing: 3) {
                Text(field.rawValue.uppercased()).font(.system(size: 9.5, weight: .semibold))
                if sortField == field {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down").font(.system(size: 8))
                }
            }
            .foregroundStyle(sortField == field ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }

    private var list: some View {
        List(filteredAndSorted) { process in
            row(process)
                .listRowInsets(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 20))
        }
        .listStyle(.plain)
    }

    private func row(_ process: SystemProcessInfo) -> some View {
        HStack {
            HStack(spacing: 8) {
                ServiceIconView(processName: process.name, size: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                Text(process.name).font(.system(size: 12)).lineLimit(1)
            }
            .frame(width: 220, alignment: .leading)

            Text(verbatim: "\(process.pid)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            Text(process.cpuLabel)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(process.cpuPercent > 50 ? .orange : .secondary)
                .frame(width: 70, alignment: .leading)

            Text(process.memoryLabel)
                .font(.system(size: 11, design: .monospaced))
                .frame(width: 90, alignment: .leading)

            Text(process.threadLabel)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            Text(process.user)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                pendingKill = process
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .frame(width: 40)
            .contextMenu {
                Button("Force Quit (SIGKILL)", role: .destructive) { pendingForceKill = process }
            }
        }
        .contentShape(Rectangle())
    }

    private func stop(_ process: SystemProcessInfo, force: Bool) {
        ProcessKiller.send(pid: process.pid, force: force)
        viewModel.logEvent(force ? .forceKill : .kill, "\(force ? "Force quit" : "Stopped") \(process.name) (PID \(process.pid)) via Task Manager")
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            await refreshOnce()
        }
    }

    private func refreshOnce() async {
        isLoading = true
        processes = await Task.detached { SystemProcessScanner.scan() }.value
        isLoading = false
    }

    private func refreshLoop() async {
        while !Task.isCancelled {
            await refreshOnce()
            try? await Task.sleep(nanoseconds: 2_500_000_000)
        }
    }
}
