import SwiftUI

struct PortsListPanel: View {
    @EnvironmentObject var viewModel: PortListViewModel
    @State private var pendingBulkStop = false
    @State private var pendingBulkForceStop = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            filterTabs
                .padding(.horizontal, 14)
                .padding(.top, 12)

            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary).font(.caption)
                TextField("Filter by port, process, or title...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                Image(systemName: "line.3.horizontal.decrease").foregroundStyle(.secondary).font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.05)))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            header
                .padding(.horizontal, 14)
                .padding(.bottom, 6)

            Divider()

            List(viewModel.filteredPorts, selection: $viewModel.selectedPortIDs) { info in
                row(info)
                    .tag(info.id)
                    .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14))
            }
            .listStyle(.plain)

            if viewModel.hasBulkSelection {
                Divider()
                bulkActionsBar
            }

            Divider()
            footer
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .alert(
            "Stop \(viewModel.selectedPorts.count) Processes?",
            isPresented: $pendingBulkStop
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Stop All", role: .destructive) { viewModel.bulkStop(viewModel.selectedPorts, force: false) }
        } message: {
            Text("Sends SIGTERM to each selected process.")
        }
        .alert(
            "Force Quit \(viewModel.selectedPorts.count) Processes?",
            isPresented: $pendingBulkForceStop
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Force Quit All", role: .destructive) { viewModel.bulkStop(viewModel.selectedPorts, force: true) }
        } message: {
            Text("Sends SIGKILL to each selected process. Unsaved work in those processes may be lost.")
        }
    }

    private var bulkActionsBar: some View {
        HStack(spacing: 10) {
            Text(verbatim: "\(viewModel.selectedPortIDs.count) selected")
                .font(.system(size: 12, weight: .medium))
            Spacer()
            Button("Clear") { viewModel.clearSelection() }
                .buttonStyle(.borderless)
            Button(role: .destructive) {
                pendingBulkStop = true
            } label: {
                Label("Stop All", systemImage: "stop.circle")
            }
            .buttonStyle(.borderless)
            Menu {
                Button("Force Quit All (SIGKILL)", role: .destructive) { pendingBulkForceStop = true }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.1))
    }

    private var filterTabs: some View {
        HStack(spacing: 8) {
            ForEach(PortsFilter.allCases) { filter in
                Button {
                    viewModel.portsFilter = filter
                } label: {
                    HStack(spacing: 5) {
                        Text(filter.rawValue).font(.system(size: 12, weight: .medium))
                        Text(verbatim: "\(count(for: filter))")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.primary.opacity(0.12)))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(viewModel.portsFilter == filter ? Color.primary.opacity(0.12) : .clear)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private func count(for filter: PortsFilter) -> Int {
        switch filter {
        case .all: return viewModel.ports.count
        case .listening: return viewModel.listeningCount
        case .external: return viewModel.externalCount
        }
    }

    private var header: some View {
        // Column widths must match `row(_:)` exactly, or the headers drift off their columns.
        HStack(spacing: 6) {
            Text("PORT").frame(width: 46, alignment: .leading)
            Text("PROCESS").frame(width: 112, alignment: .leading)
            Text("PID").frame(width: 50, alignment: .leading)
            Text("TITLE").lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            Text("STATUS").frame(width: 78, alignment: .leading)
        }
        .font(.system(size: 9.5, weight: .semibold))
        .foregroundStyle(.secondary)
    }

    private func row(_ info: PortInfo) -> some View {
        HStack(spacing: 6) {
            Text(verbatim: "\(info.port)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .frame(width: 46, alignment: .leading)

            HStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    ServiceIconView(processName: info.processName, size: 16)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Circle().fill(info.category.color).frame(width: 5, height: 5)
                        .overlay(Circle().stroke(.background, lineWidth: 1))
                }
                Text(info.processName).font(.system(size: 12)).lineLimit(1)
            }
            .frame(width: 112, alignment: .leading)

            Text(verbatim: "\(info.pid)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)

            Text(info.detectedLabel)
                .font(.system(size: 12))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 5) {
                Circle().fill(info.status.color).frame(width: 6, height: 6)
                Text(info.status.rawValue).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .frame(width: 78, alignment: .leading)
        }
        .contentShape(Rectangle())
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Text(verbatim: "\(viewModel.ports.count) ports").font(.caption).foregroundStyle(.secondary)
            statusDot(.listening, count: viewModel.listeningCount)
            statusDot(.noResponse, count: viewModel.noResponseCount)
            statusDot(.error, count: viewModel.errorCount)
            Spacer()
        }
    }

    private func statusDot(_ status: PortStatus, count: Int) -> some View {
        HStack(spacing: 4) {
            Circle().fill(status.color).frame(width: 6, height: 6)
            Text(verbatim: "\(status.rawValue) \(count)").font(.caption2).foregroundStyle(.secondary)
        }
    }
}
