import SwiftUI

private struct ProcessGroup: Identifiable {
    let id: String
    let name: String
    let ports: [PortInfo]
}

struct ProcessesView: View {
    @EnvironmentObject var viewModel: PortListViewModel
    @State private var pendingKillPortless: DevProcessInfo?
    @State private var pendingForceKillPortless: DevProcessInfo?

    private var groups: [ProcessGroup] {
        let grouped = Dictionary(grouping: viewModel.ports, by: \.processName)
        return grouped.map { ProcessGroup(id: $0.key, name: $0.key, ports: $0.value.sorted { $0.port < $1.port }) }
            .sorted { $0.ports.count > $1.ports.count }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Processes").font(.title2.bold()).padding(.bottom, 4)
                Text(verbatim: "\(groups.count) distinct processes across \(viewModel.ports.count) ports")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !viewModel.portlessDevProcesses.isEmpty {
                    portlessSection
                }

                ForEach(groups) { group in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(group.ports) { info in
                                Button {
                                    viewModel.selectedPortID = info.id
                                    viewModel.sidebarSection = .overview
                                } label: {
                                    HStack {
                                        Circle().fill(info.category.color).frame(width: 6, height: 6)
                                        Text(verbatim: "Port \(info.port)").font(.system(size: 12, design: .monospaced))
                                        Text(verbatim: "PID \(info.pid)").font(.caption2).foregroundStyle(.secondary)
                                        Spacer()
                                        Text(info.detectedLabel).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                }
                                .buttonStyle(.plain)
                                if !info.workingDirectory.isEmpty {
                                    Text(info.workingDirectory)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                        .padding(.leading, 14)
                                }
                            }
                        }
                        .padding(.top, 6)
                    } label: {
                        HStack {
                            ServiceIconView(processName: group.name, size: 20)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                            Text(group.name).font(.system(size: 13, weight: .semibold))
                            Text(verbatim: "\(group.ports.count) port\(group.ports.count == 1 ? "" : "s")")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.primary.opacity(0.1)))
                            if let user = group.ports.first?.user, !user.isEmpty {
                                Text(user).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(0.04)))
                }
            }
            .padding(20)
        }
        .alert("Stop \(pendingKillPortless?.name ?? "")?", isPresented: Binding(get: { pendingKillPortless != nil }, set: { if !$0 { pendingKillPortless = nil } })) {
            Button("Cancel", role: .cancel) { pendingKillPortless = nil }
            Button("Stop", role: .destructive) {
                if let info = pendingKillPortless { viewModel.kill(info, force: false) }
                pendingKillPortless = nil
            }
        } message: {
            Text(verbatim: "Sends SIGTERM to PID \(pendingKillPortless?.pid ?? 0).")
        }
        .alert("Force Quit \(pendingForceKillPortless?.name ?? "")?", isPresented: Binding(get: { pendingForceKillPortless != nil }, set: { if !$0 { pendingForceKillPortless = nil } })) {
            Button("Cancel", role: .cancel) { pendingForceKillPortless = nil }
            Button("Force Quit", role: .destructive) {
                if let info = pendingForceKillPortless { viewModel.kill(info, force: true) }
                pendingForceKillPortless = nil
            }
        } message: {
            Text(verbatim: "Sends SIGKILL to PID \(pendingForceKillPortless?.pid ?? 0). Unsaved work may be lost.")
        }
    }

    private var portlessSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "eye.slash").foregroundStyle(.orange)
                Text("Other Dev Processes").font(.system(size: 13, weight: .semibold))
                Text("no active port").font(.caption2).foregroundStyle(.secondary)
            }
            Text("These look like dev-workflow processes but hold no listening socket right now, so they don't show up as a \"port\" — often a dev server mid-restart, or a worker left running after its listener died.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                ForEach(viewModel.portlessDevProcesses) { process in
                    HStack {
                        Image(systemName: "cpu").foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(process.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                            Text(verbatim: "PID \(process.pid) · \(process.user)").font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(process.memoryLabel).font(.system(size: 12, weight: .semibold, design: .monospaced))
                        Button {
                            pendingKillPortless = process
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .contextMenu {
                            Button("Force Quit (SIGKILL)", role: .destructive) { pendingForceKillPortless = process }
                        }
                    }
                    .padding(9)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Color.orange.opacity(0.07)))
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.orange.opacity(0.3), lineWidth: 1))
    }
}
