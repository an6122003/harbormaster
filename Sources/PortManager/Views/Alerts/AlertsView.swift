import SwiftUI

struct AlertsView: View {
    @EnvironmentObject var viewModel: PortListViewModel

    private var alertEvents: [AppEvent] {
        viewModel.events.filter { $0.kind == .alert || $0.kind == .recovered }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Alerts").font(.title2.bold())

                if viewModel.alertPorts.isEmpty {
                    ContentUnavailableCompat(
                        title: "All Clear",
                        message: "Every detected port is responding normally.",
                        systemImage: "checkmark.seal"
                    )
                    .frame(height: 200)
                } else {
                    Text(verbatim: "\(viewModel.alertPorts.count) port\(viewModel.alertPorts.count == 1 ? "" : "s") need attention")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    VStack(spacing: 8) {
                        ForEach(viewModel.alertPorts) { info in
                            Button {
                                viewModel.selectedPortID = info.id
                                viewModel.sidebarSection = .overview
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: info.status == .error ? "exclamationmark.octagon.fill" : "exclamationmark.triangle.fill")
                                        .foregroundStyle(info.status.color)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(verbatim: "Port \(info.port) — \(info.processName)").font(.system(size: 13, weight: .medium))
                                        Text(info.detectedLabel).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(info.status.rawValue).font(.caption).foregroundStyle(info.status.color)
                                }
                                .padding(10)
                                .background(RoundedRectangle(cornerRadius: 8).fill(info.status.color.opacity(0.08)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !alertEvents.isEmpty {
                    Text("Recent Activity").font(.headline).padding(.top, 10)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(alertEvents.prefix(20)) { event in
                            HStack(spacing: 8) {
                                Image(systemName: event.kind.systemImage)
                                    .foregroundStyle(event.kind == .alert ? .red : .green)
                                Text(event.message).font(.caption)
                                Spacer()
                                Text(event.timestamp, style: .time).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}
