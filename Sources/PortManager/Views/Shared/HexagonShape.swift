import SwiftUI

/// A regular hexagon — used as a simple, original nod to Node.js's brand shape
/// (not a trace of the official logo) for processes with no installed .app icon.
struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        for i in 0..<6 {
            let angle = Angle(degrees: Double(i) * 60 - 90).radians
            let point = CGPoint(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}
