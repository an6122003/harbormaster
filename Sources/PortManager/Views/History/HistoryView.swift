import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var viewModel: PortListViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("History").font(.title2.bold())
                Spacer()
                if !viewModel.events.isEmpty {
                    Button("Clear") { viewModel.events.removeAll() }
                        .buttonStyle(.borderless)
                }
            }
            .padding(20)

            Divider()

            if viewModel.events.isEmpty {
                ContentUnavailableCompat(
                    title: "No Activity Yet",
                    message: "Kills, alerts, and terminal reveals will show up here as they happen.",
                    systemImage: "clock"
                )
            } else {
                List(viewModel.events) { event in
                    HStack(spacing: 10) {
                        Image(systemName: event.kind.systemImage)
                            .foregroundStyle(color(for: event.kind))
                            .frame(width: 18)
                        Text(event.message).font(.system(size: 12))
                        Spacer()
                        Text(event.timestamp, style: .time).font(.caption2).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 3)
                }
                .listStyle(.plain)
            }
        }
    }

    private func color(for kind: AppEvent.Kind) -> Color {
        switch kind {
        case .kill, .forceKill: return .red
        case .alert: return .orange
        case .recovered: return .green
        case .revealTerminal: return .blue
        case .info: return .secondary
        }
    }
}
