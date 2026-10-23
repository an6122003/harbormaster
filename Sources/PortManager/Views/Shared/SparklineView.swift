import SwiftUI

/// A minimal line sparkline over real recorded samples (never fabricated —
/// renders nothing until at least two real data points exist).
struct SparklineView: View {
    let values: [Int]
    var color: Color = .green

    var body: some View {
        GeometryReader { geo in
            if values.count >= 2 {
                let maxValue = max(values.max() ?? 1, 1)
                let minValue = min(values.min() ?? 0, maxValue - 1)
                let range = max(CGFloat(maxValue - minValue), 1)
                let stepX = geo.size.width / CGFloat(values.count - 1)

                Path { path in
                    for (index, value) in values.enumerated() {
                        let x = CGFloat(index) * stepX
                        let normalized = CGFloat(value - minValue) / range
                        let y = geo.size.height * (1 - normalized)
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
            }
        }
    }
}
