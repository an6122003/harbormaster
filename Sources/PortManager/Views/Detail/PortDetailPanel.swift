import SwiftUI
import AppKit

enum DetailTab: String, CaseIterable {
    case preview = "Preview"
    case details = "Details"
    case headers = "Headers"
    case connections = "Connections"
}

struct PortDetailPanel: View {
    @EnvironmentObject var viewModel: PortListViewModel
    let info: PortInfo

    @State private var selectedTab: DetailTab = .preview
    @State private var connections: [ConnectionInfo] = []
    @State private var pendingKill = false
    @State private var pendingForceKill = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            divider

            tabBar

            Group {
                if selectedTab == .preview {
                    previewContent
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            switch selectedTab {
                            case .preview: EmptyView()
                            case .details: detailsContent
                            case .headers: headersContent
                            case .connections: connectionsContent
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            divider
            actionButtons
                .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PanelTheme.background)
        .onAppear {
            if let requested = viewModel.requestedDetailTab { selectedTab = requested }
        }
        .onChange(of: viewModel.requestedDetailTab) { requested in
            if let requested { selectedTab = requested }
        }
        .task(id: "\(info.id)-\(selectedTab)") {
            guard selectedTab == .connections else { return }
            let port = info.port
            connections = await Task.detached { ConnectionInspector.connections(forPort: port) }.value
        }
        .alert("Stop \(info.processName)?", isPresented: $pendingKill) {
            Button("Cancel", role: .cancel) {}
            Button("Stop", role: .destructive) { viewModel.kill(info, force: false) }
        } message: {
            Text(verbatim: "Sends SIGTERM to PID \(info.pid) on port \(info.port).")
        }
        .alert("Force Quit \(info.processName)?", isPresented: $pendingForceKill) {
            Button("Cancel", role: .cancel) {}
            Button("Force Quit", role: .destructive) { viewModel.kill(info, force: true) }
        } message: {
            Text(verbatim: "Sends SIGKILL to PID \(info.pid). Unsaved work may be lost.")
        }
    }

    private var divider: some View {
        Rectangle().fill(PanelTheme.border).frame(height: 1)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                Text(info.detectedLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PanelTheme.textPrimary)
                    .lineLimit(2)
                Spacer()
                Button {
                    viewModel.selectedPortID = nil
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(PanelTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 5) {
                Circle().fill(info.status.color).frame(width: 7, height: 7)
                Text(info.status.rawValue).font(.caption).foregroundStyle(PanelTheme.textSecondary)
            }
        }
        .padding(16)
    }

    private var tabBar: some View {
        HStack(spacing: 12) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 7) {
                        Text(tab.rawValue)
                            .font(.system(size: 11.5, weight: selectedTab == tab ? .semibold : .regular))
                            .foregroundStyle(selectedTab == tab ? PanelTheme.textPrimary : PanelTheme.textSecondary)
                            .lineLimit(1)
                            .fixedSize()
                        Rectangle()
                            .fill(selectedTab == tab ? PanelTheme.accent : .clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
    }

    private var previewContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Live Preview").font(.system(size: 13, weight: .semibold)).foregroundStyle(PanelTheme.textPrimary)
                    Spacer()
                    HStack(spacing: 4) {
                        Circle().fill(info.reachable ? Color.green : PanelTheme.textTertiary).frame(width: 6, height: 6)
                        Text(info.reachable ? "Live" : "Offline").font(.caption2).foregroundStyle(PanelTheme.textSecondary)
                    }
                }

                if let url = info.previewURL {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        HStack {
                            Text(url.absoluteString.replacingOccurrences(of: "127.0.0.1", with: "localhost"))
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundStyle(PanelTheme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 11))
                                .foregroundStyle(PanelTheme.textSecondary)
                        }
                        .padding(9)
                        .background(RoundedRectangle(cornerRadius: PanelTheme.cornerRadius).fill(PanelTheme.card))
                        .overlay(RoundedRectangle(cornerRadius: PanelTheme.cornerRadius).strokeBorder(PanelTheme.border, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                Group {
                    if DemoMode.isEnabled, info.reachable {
                        WebView(html: DemoData.previewHTML(title: info.title))
                    } else if let url = info.previewURL, info.reachable {
                        WebView(url: url)
                    } else {
                        previewEmptyState
                    }
                }
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: PanelTheme.cornerRadius))
                .overlay(RoundedRectangle(cornerRadius: PanelTheme.cornerRadius).strokeBorder(PanelTheme.border, lineWidth: 1))

                HStack(spacing: 10) {
                    statTile("STATUS CODE", value: info.httpStatus != nil ? info.statusCodeLabel : "—", valueColor: statusCodeColor)
                    statTile("LATENCY", value: info.latencyLabel, valueColor: PanelTheme.textPrimary)
                    statTile("MEMORY", value: info.memoryLabel, valueColor: PanelTheme.textPrimary, sparklineID: info.id)
                }

                divider.padding(.vertical, 2)

                detailRow("Process", "\(info.processName) (PID \(info.pid))", icon: "cpu")
                if !info.command.isEmpty { detailRow("Command", info.command, icon: "terminal") }
                if !info.workingDirectory.isEmpty { detailRow("Working Directory", info.workingDirectory, icon: "folder") }
                if !info.startedAtRaw.isEmpty { detailRow("Started", info.startedAtRaw, icon: "clock") }
                if !info.uptimeRaw.isEmpty { detailRow("Uptime", info.uptimeRaw, icon: "hourglass") }
                if !info.nodeEnv.isEmpty { detailRow("Environment", info.nodeEnv, icon: "leaf") }
                if !info.user.isEmpty { detailRow("User", info.user, icon: "person") }
                if !info.runtimeVersion.isEmpty { detailRow("Version", info.runtimeVersion, icon: "number.circle") }
            }
            .padding(16)
        }
    }

    private var previewEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "eye.slash").font(.system(size: 26)).foregroundStyle(PanelTheme.textTertiary)
            Text("No Live Preview").font(.system(size: 13, weight: .semibold)).foregroundStyle(PanelTheme.textPrimary)
            Text(
                info.reachable
                    ? "This port doesn't look like a browsable web page."
                    : "This port isn't responding to HTTP right now."
            )
            .font(.caption2)
            .foregroundStyle(PanelTheme.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 240)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PanelTheme.card)
    }

    private var statusCodeColor: Color {
        guard let code = info.httpStatus else { return PanelTheme.textSecondary }
        switch code {
        case 200..<400: return .green
        case 400..<500: return .orange
        default: return PanelTheme.destructive
        }
    }

    private func statTile(_ label: String, value: String, valueColor: Color, sparklineID: PortInfo.ID? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 9, weight: .semibold)).foregroundStyle(PanelTheme.textTertiary)
            Text(value).font(.system(size: 14, weight: .semibold)).foregroundStyle(valueColor).lineLimit(1)
            if let sparklineID, let history = viewModel.memoryHistory[sparklineID], history.count >= 2 {
                SparklineView(values: history, color: PanelTheme.accent)
                    .frame(height: 16)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: PanelTheme.cornerRadius).fill(PanelTheme.card))
        .overlay(RoundedRectangle(cornerRadius: PanelTheme.cornerRadius).strokeBorder(PanelTheme.border, lineWidth: 1))
    }

    private var detailsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            detailRow("Port", "\(info.port)", icon: "number")
            detailRow("Protocol", info.protocolLabel, icon: "antenna.radiowaves.left.and.right")
            detailRow("Status Code", info.statusCodeLabel, icon: "checkmark.shield")
            detailRow("Process", "\(info.processName) (\(info.pid))", icon: "cpu")
            detailRow("Memory", info.memoryLabel, icon: "memorychip")
            if !info.user.isEmpty { detailRow("User", info.user, icon: "person") }
            if !info.workingDirectory.isEmpty { detailRow("Working Dir", info.workingDirectory, icon: "folder") }
            if !info.startedAtRaw.isEmpty { detailRow("Started", info.startedAtRaw, icon: "clock") }
            if !info.uptimeRaw.isEmpty { detailRow("Uptime", info.uptimeRaw, icon: "hourglass") }

            divider.padding(.vertical, 2)

            urlField("Local URL", url: info.previewURL)
            if let networkURL = info.networkURL(lanIP: viewModel.lanIP) {
                urlField("Network URL", url: networkURL)
            }

            divider.padding(.vertical, 2)

            detailRow("Status", info.isExternallyBound ? "Listening on 0.0.0.0" : "Listening on 127.0.0.1", icon: "wifi")
            detailRow("Connections", "\(info.connectionsCount) active", icon: "point.3.connected.trianglepath.dotted")
        }
    }

    private func detailRow(_ label: String, _ value: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(PanelTheme.textTertiary).font(.system(size: 11)).frame(width: 14)
            Text(label).font(.system(size: 12)).foregroundStyle(PanelTheme.textSecondary).frame(width: 84, alignment: .leading)
            Text(value).font(.system(size: 12)).foregroundStyle(PanelTheme.textPrimary).textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    private func urlField(_ label: String, url: URL?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 12)).foregroundStyle(PanelTheme.textSecondary)
            HStack {
                Text(url?.absoluteString ?? "—")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(PanelTheme.textPrimary)
                    .lineLimit(1)
                    .textSelection(.enabled)
                Spacer()
                if let url {
                    Button {
                        copyToPasteboard(url.absoluteString)
                    } label: {
                        Image(systemName: "doc.on.doc").foregroundStyle(PanelTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(9)
            .background(RoundedRectangle(cornerRadius: PanelTheme.cornerRadius).fill(PanelTheme.card))
            .overlay(RoundedRectangle(cornerRadius: PanelTheme.cornerRadius).strokeBorder(PanelTheme.border, lineWidth: 1))
        }
    }

    private var headersContent: some View {
        Group {
            if info.headers.isEmpty {
                Text("No response headers captured.").font(.caption).foregroundStyle(PanelTheme.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(info.headers.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(key).font(.system(size: 12, weight: .semibold)).foregroundStyle(PanelTheme.textPrimary)
                            Text(value)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(PanelTheme.textSecondary)
                                .textSelection(.enabled)
                        }
                        .padding(9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: PanelTheme.cornerRadius).fill(PanelTheme.card))
                    }
                }
            }
        }
    }

    private var connectionsContent: some View {
        Group {
            if connections.isEmpty {
                Text("No active connections right now.").font(.caption).foregroundStyle(PanelTheme.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(connections) { connection in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(connection.remoteAddress).font(.system(size: 11, design: .monospaced)).foregroundStyle(PanelTheme.textPrimary)
                            Text(connection.state).font(.caption2).foregroundStyle(PanelTheme.textSecondary)
                        }
                        .padding(9)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: PanelTheme.cornerRadius).fill(PanelTheme.card))
                    }
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 8) {
            Button {
                if let url = info.previewURL { NSWorkspace.shared.open(url) }
            } label: {
                Label("Open in Browser", systemImage: "globe")
            }
            .buttonStyle(DashboardButtonStyle(kind: .primary))
            .disabled(!info.reachable)
            .opacity(info.reachable ? 1 : 0.4)

            Button {
                viewModel.revealTerminal(for: info)
            } label: {
                Label("Open in Terminal", systemImage: "terminal")
            }
            .buttonStyle(DashboardButtonStyle(kind: .secondary))

            Button {
                if let url = info.previewURL { copyToPasteboard(url.absoluteString) }
            } label: {
                Label("Copy Local URL", systemImage: "link")
            }
            .buttonStyle(DashboardButtonStyle(kind: .secondary))

            Button {
                pendingKill = true
            } label: {
                Label("Stop Process", systemImage: "stop.circle")
            }
            .buttonStyle(DashboardButtonStyle(kind: .destructive))
            .contextMenu {
                Button("Force Quit (SIGKILL)", role: .destructive) { pendingForceKill = true }
            }
        }
    }

    private func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
