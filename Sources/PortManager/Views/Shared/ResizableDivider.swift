import SwiftUI
import AppKit

/// A draggable divider that resizes an adjacent panel by adjusting `width`.
/// Set `invert` to true when the panel being resized is to the *left* of the
/// divider (dragging left should grow it, not shrink it).
struct ResizableDivider: View {
    @Binding var width: CGFloat
    let minWidth: CGFloat
    let maxWidth: CGFloat
    var invert: Bool = false

    @State private var widthAtDragStart: CGFloat?

    var body: some View {
        Divider()
            .frame(width: 7)
            .contentShape(Rectangle())
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        let base = widthAtDragStart ?? width
                        if widthAtDragStart == nil { widthAtDragStart = width }
                        let delta = invert ? -value.translation.width : value.translation.width
                        width = min(max(base + delta, minWidth), maxWidth)
                    }
                    .onEnded { _ in widthAtDragStart = nil }
            )
    }
}
