import SwiftUI
import AppKit

@main
struct PortManagerApp: App {
    @StateObject private var viewModel = PortListViewModel()

    var body: some Scene {
        WindowGroup("Port Manager", id: "main") {
            ContentView()
                .environmentObject(viewModel)
        }
        .defaultSize(width: 1240, height: 720)
        .defaultPosition(.center)

        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(viewModel)
        } label: {
            MenuBarIconView()
        }
        .menuBarExtraStyle(.window)
    }
}

/// Status items bridge through to AppKit, where SwiftUI's `.resizable()` +
/// `.aspectRatio()` didn't reliably constrain the image's effective size — the
/// underlying NSImage's native size (~800pt, since that's its pixel dimensions)
/// could leak through and break the status item's layout, which is almost
/// certainly why the icon disappeared entirely rather than just looking wrong.
/// Sizing the NSImage itself directly, before SwiftUI ever sees it, avoids that.
private struct MenuBarIconView: View {
    private static let icon = AppLogo.sized(toHeight: 18)

    var body: some View {
        Image(nsImage: Self.icon)
    }
}
