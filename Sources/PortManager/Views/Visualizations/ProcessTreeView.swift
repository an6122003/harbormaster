import SwiftUI

struct ProcessTreeView: View {
    @EnvironmentObject var viewModel: PortListViewModel
    @State private var chain: [ProcessTreeNode] = []

    var body: some View {
        Group {
            if let info = viewModel.selectedPort {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(chain.enumerated()), id: \.element.id) { index, node in
                            HStack(alignment: .top, spacing: 10) {
                                VStack(spacing: 0) {
                                    Circle()
                                        .fill(node.pid == info.pid ? Color.accentColor : Color.secondary.opacity(0.5))
                                        .frame(width: 9, height: 9)
                                    if index < chain.count - 1 {
                                        Rectangle().fill(Color.secondary.opacity(0.3)).frame(width: 1.5).frame(maxHeight: .infinity)
                                    }
                                }
                                .frame(width: 9)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(node.name).font(.system(size: 13, weight: node.pid == info.pid ? .semibold : .regular))
                                        Text(verbatim: "PID \(node.pid)").font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Text(node.command)
                                        .font(.system(size: 10.5, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .padding(.bottom, 18)
                            }
                        }
                    }
                    .padding(20)
                }
                .task(id: info.pid) {
                    let pid = info.pid
                    chain = await Task.detached { ProcessTree.ancestry(of: pid) }.value
                }
            } else {
                ContentUnavailableCompat(
                    title: "No Process Selected",
                    message: "Select a port from the list to see its process ancestry, from the launching shell/app down to the running server."
                )
            }
        }
    }
}
