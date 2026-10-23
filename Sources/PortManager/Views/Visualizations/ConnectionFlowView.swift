import SwiftUI

struct ConnectionFlowView: View {
    @EnvironmentObject var viewModel: PortListViewModel
    @State private var connections: [ConnectionInfo] = []
    @State private var isLoading = false

    var body: some View {
        Group {
            if let info = viewModel.selectedPort {
                ScrollView {
                    HStack(alignment: .top, spacing: 40) {
                        VStack(spacing: 6) {
                            Image(systemName: "shippingbox.fill")
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(Circle().fill(info.category.color))
                            Text(verbatim: "Port \(info.port)").font(.system(size: 12, weight: .semibold))
                            Text(info.processName).font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(.top, 40)

                        if connections.isEmpty {
                            Text(isLoading ? "Loading connections…" : "No active connections right now.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 50)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(connections) { connection in
                                    HStack(spacing: 8) {
                                        Rectangle().fill(Color.secondary.opacity(0.3)).frame(width: 24, height: 1.5)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(connection.remoteAddress).font(.system(size: 12, design: .monospaced))
                                            Text(connection.state).font(.caption2).foregroundStyle(.secondary)
                                        }
                                        .padding(8)
                                        .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.06)))
                                    }
                                }
                            }
                            .padding(.top, 20)
                        }
                    }
                    .padding(30)
                }
                .task(id: info.port) {
                    isLoading = true
                    let port = info.port
                    connections = await Task.detached { ConnectionInspector.connections(forPort: port) }.value
                    isLoading = false
                }
            } else {
                ContentUnavailableCompat(
                    title: "No Process Selected",
                    message: "Select a port to see its live inbound/outbound TCP connections.",
                    systemImage: "point.3.connected.trianglepath.dotted"
                )
            }
        }
    }
}
