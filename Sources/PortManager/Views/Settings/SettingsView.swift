import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: PortListViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings").font(.title2.bold())

                GroupBox("Monitoring") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Auto-refresh ports every 4 seconds", isOn: $viewModel.autoRefresh)
                        if let lanIP = viewModel.lanIP {
                            HStack {
                                Text("Detected LAN IP").foregroundStyle(.secondary)
                                Spacer()
                                Text(lanIP).font(.system(.body, design: .monospaced))
                            }
                        }
                        HStack {
                            Text("Ports currently tracked").foregroundStyle(.secondary)
                            Spacer()
                            Text(verbatim: "\(viewModel.ports.count)")
                        }
                    }
                    .padding(8)
                }

                GroupBox("About") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Port Manager visualizes what's running on your machine's local ports, lets you preview and open each service, and stop processes you no longer need.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Detection uses lsof/ps locally — nothing leaves this Mac.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
        }
    }
}
