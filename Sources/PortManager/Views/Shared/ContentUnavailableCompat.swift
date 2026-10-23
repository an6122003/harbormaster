import SwiftUI

/// A minimal `ContentUnavailableView` stand-in — that API needs macOS 14,
/// and this app's deployment target is macOS 13 (for `MenuBarExtra(.window)`).
struct ContentUnavailableCompat: View {
    let title: String
    let message: String
    var systemImage: String = "square.dashed"

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage).font(.system(size: 32)).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
}
