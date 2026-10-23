import SwiftUI
import AppKit

struct MenuBarContentView: View {
    @EnvironmentObject var viewModel: PortListViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Ports")
                    .font(.headline)
                Spacer()
                if viewModel.isLoading {
                    ProgressView().controlSize(.small)
                }
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }

            Divider()

            if viewModel.ports.isEmpty {
                Text("No listening ports found")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .padding(.vertical, 8)
            } else {
                let rowHeight: CGFloat = 34
                let contentHeight = CGFloat(viewModel.ports.count) * rowHeight + 8
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(viewModel.ports) { info in
                            row(info)
                        }
                    }
                }
                // MenuBarExtra(.window) sizes its panel to fit content; a bare
                // .frame(maxHeight:) with no floor collapses to zero height here
                // (unlike a real WindowGroup window, which always has concrete bounds).
                .frame(height: min(contentHeight, 340), alignment: .top)
            }

            Divider()

            HStack {
                Button("Open Port Manager") {
                    if let existing = NSApp.windows.first(where: { $0.title == "Port Manager" && $0.isVisible }) {
                        existing.makeKeyAndOrderFront(nil)
                    } else {
                        openWindow(id: "main")
                    }
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(12)
        .frame(width: 320)
        .task {
            await viewModel.refresh()
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
            Text("This process's session traces back to \(viewModel.appRevealCandidate?.name ?? "this app") — there's no specific window/tab to jump to, just the app itself.")
        }
    }

    private func row(_ info: PortInfo) -> some View {
        HStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                ServiceIconView(processName: info.processName, size: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4.5))
                Circle().fill(info.status.color).frame(width: 6, height: 6)
                    .overlay(Circle().stroke(.background, lineWidth: 1))
            }

            Text(verbatim: "\(info.port)")
                .monospacedDigit()
                .fontWeight(.semibold)
                .frame(width: 42, alignment: .leading)

            VStack(alignment: .leading, spacing: 0) {
                Text(info.processName)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Text(info.detectedLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                if let url = info.previewURL {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Image(systemName: "safari")
            }
            .buttonStyle(.borderless)
            .disabled(!info.reachable)

            Button {
                viewModel.revealTerminal(for: info)
            } label: {
                Image(systemName: "terminal")
            }
            .buttonStyle(.borderless)
            .help("Reveal owning terminal window")

            Button(role: .destructive) {
                viewModel.kill(info)
            } label: {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
        }
    }
}
