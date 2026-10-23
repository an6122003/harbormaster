import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var viewModel: PortListViewModel

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
            Divider()

            VStack(spacing: 0) {
                TopBarView()
                Divider()
                sectionBody
            }
        }
        .frame(minWidth: 1180, minHeight: 680)
        .task {
            await viewModel.refresh()
            viewModel.startAutoRefresh()
            await SnapshotRunner.runIfRequested(viewModel: viewModel)
        }
        .alert(
            "No Exact Tab Found",
            isPresented: Binding(get: { viewModel.revealMessage != nil }, set: { if !$0 { viewModel.revealMessage = nil } })
        ) {
            Button("OK") { viewModel.revealMessage = nil }
        } message: {
            Text(viewModel.revealMessage ?? "")
        }
        .alert(
            "Bring \(viewModel.appRevealCandidate?.name ?? "App") to the Front?",
            isPresented: Binding(get: { viewModel.appRevealCandidate != nil }, set: { if !$0 { viewModel.appRevealCandidate = nil } })
        ) {
            Button("Cancel", role: .cancel) { viewModel.appRevealCandidate = nil }
            Button("Bring to Front") { viewModel.confirmAppReveal() }
        } message: {
            Text("This process's session traces back to \(viewModel.appRevealCandidate?.name ?? "this app") — there's no specific window/tab to jump to (no scripting support for that), just the app itself.")
        }
    }

    @ViewBuilder
    private var sectionBody: some View {
        switch viewModel.sidebarSection {
        case .overview:
            DashboardView(showVisualization: true)
        case .ports:
            DashboardView(showVisualization: false)
        case .processes:
            ProcessesView()
        case .taskManager:
            TaskManagerView()
        case .alerts:
            AlertsView()
        case .history:
            HistoryView()
        case .settings:
            SettingsView()
        }
    }
}
