import SwiftUI

/// Fixed dark palette for the detail/inspector panel, matching the original
/// dashboard mockup's look regardless of the host window's light/dark mode —
/// an intentionally-dark inspector, same idea as pro app panels that stay dark
/// even outside system dark mode. Every color here is explicit (not adaptive)
/// since the background itself is fixed.
enum PanelTheme {
    static let background = Color(red: 0.043, green: 0.055, blue: 0.078)
    static let card = Color.white.opacity(0.05)
    static let border = Color.white.opacity(0.09)
    static let accent = Color(red: 0.23, green: 0.51, blue: 0.98)
    static let destructive = Color(red: 0.94, green: 0.33, blue: 0.31)
    static let textPrimary = Color.white.opacity(0.95)
    static let textSecondary = Color.white.opacity(0.52)
    static let textTertiary = Color.white.opacity(0.32)
    static let cornerRadius: CGFloat = 9
}

struct DashboardButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, destructive }
    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: PanelTheme.cornerRadius)
                    .fill(background(pressed: configuration.isPressed))
            )
            .overlay(
                RoundedRectangle(cornerRadius: PanelTheme.cornerRadius)
                    .strokeBorder(kind == .destructive ? PanelTheme.destructive.opacity(0.35) : .clear, lineWidth: 1)
            )
            .foregroundStyle(foreground)
    }

    private func background(pressed: Bool) -> Color {
        switch kind {
        case .primary: return PanelTheme.accent.opacity(pressed ? 0.75 : 1)
        case .secondary: return Color.white.opacity(pressed ? 0.14 : 0.08)
        case .destructive: return PanelTheme.destructive.opacity(pressed ? 0.22 : 0.13)
        }
    }

    private var foreground: Color {
        switch kind {
        case .primary: return .white
        case .secondary: return PanelTheme.textPrimary
        case .destructive: return PanelTheme.destructive
        }
    }
}
