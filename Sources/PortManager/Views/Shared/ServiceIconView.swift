import SwiftUI
import AppKit

/// Shows the real installed app icon when one resolves (Discord, Docker Desktop,
/// VS Code, …), an original brand-color glyph for well-known CLI runtimes that
/// have no .app bundle of their own (node, python, bare docker daemon/CLI), or a
/// generic fallback otherwise.
struct ServiceIconView: View {
    let processName: String
    var size: CGFloat = 26

    var body: some View {
        Group {
            if let nsImage = AppIconResolver.icon(forProcessName: processName) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                runtimeGlyph
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var runtimeGlyph: some View {
        switch processName.lowercased() {
        case "node":
            ZStack {
                HexagonShape().fill(Color(red: 0.22, green: 0.60, blue: 0.24))
                Text("N")
                    .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

        case "docker", "com.docker.backend", "dockerd", "docker-compose":
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(Color(red: 0.14, green: 0.59, blue: 0.91))
                .overlay(
                    HStack(spacing: size * 0.06) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: size * 0.05)
                                .fill(.white)
                                .frame(width: size * 0.2, height: size * 0.2)
                        }
                    }
                )

        case "python", "python3":
            ZStack {
                Circle().fill(Color(red: 0.22, green: 0.46, blue: 0.68))
                    .frame(width: size * 0.72, height: size * 0.72)
                    .offset(x: -size * 0.14, y: -size * 0.14)
                Circle().fill(Color(red: 1.0, green: 0.83, blue: 0.26))
                    .frame(width: size * 0.72, height: size * 0.72)
                    .offset(x: size * 0.14, y: size * 0.14)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22))

        case "ruby":
            Diamond()
                .fill(Color(red: 0.75, green: 0.11, blue: 0.14))
                .frame(width: size * 0.82, height: size * 0.82)

        case "redis-server", "redis":
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(Color(red: 0.60, green: 0.09, blue: 0.13))
                .overlay(Image(systemName: "cylinder.fill").font(.system(size: size * 0.5)).foregroundStyle(.white))

        default:
            RoundedRectangle(cornerRadius: size * 0.26)
                .fill(Color.gray.opacity(0.85))
                .overlay(
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: size * 0.5))
                        .foregroundStyle(.white)
                )
        }
    }
}

private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}
