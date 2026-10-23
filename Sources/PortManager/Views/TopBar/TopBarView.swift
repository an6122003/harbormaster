import SwiftUI
import AppKit

struct TopBarView: View {
    @EnvironmentObject var viewModel: PortListViewModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(nsImage: AppLogo.rawImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .frame(width: 34, height: 34)
                    .background(RoundedRectangle(cornerRadius: 9).fill(Color.accentColor.opacity(0.15)))

                VStack(alignment: .leading, spacing: 0) {
                    Text("Port Manager").font(.system(size: 15, weight: .semibold))
                    Text("Visualize. Manage. Connect.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 20)

            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search ports, processes, or commands...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                Text("⌘K").font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
            .frame(maxWidth: 420)
            .background(
                Button("") { searchFocused = true }
                    .keyboardShortcut("k", modifiers: .command)
                    .opacity(0)
            )

            Spacer(minLength: 20)

            HStack(spacing: 14) {
                Toggle("Auto-refresh", isOn: $viewModel.autoRefresh)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                Text("Auto-refresh").font(.caption).foregroundStyle(.secondary)

                iconButton("arrow.clockwise", help: "Refresh now") {
                    Task { await viewModel.refresh() }
                }
                iconButton("terminal", help: "Reveal terminal for selected port", disabled: viewModel.selectedPort == nil) {
                    if let port = viewModel.selectedPort {
                        viewModel.revealTerminal(for: port)
                    }
                }
                iconButton("list.bullet", help: "Ports list") {
                    viewModel.sidebarSection = .ports
                }
                iconButton("gearshape", help: "Settings") {
                    viewModel.sidebarSection = .settings
                }
                Menu {
                    Button("About Port Manager") { NSApp.orderFrontStandardAboutPanel(nil) }
                    Divider()
                    Button("Quit", role: .destructive) { NSApp.terminate(nil) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.thinMaterial)
    }

    private func iconButton(_ systemImage: String, help: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.borderless)
        .help(help)
        .disabled(disabled)
    }
}
