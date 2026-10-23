import SwiftUI

private struct PortGroup: Identifiable {
    let pid: Int32
    let ports: [PortInfo]
    var id: Int32 { pid }
}

struct NetworkMapView: View {
    @EnvironmentObject var viewModel: PortListViewModel
    @State private var zoom: CGFloat = 1.0
    @State private var hasPositioned = false
    @GestureState private var pinchDelta: CGFloat = 1.0
    private static let centralNodeID = "central-node"
    private static let originID = "map-origin"

    private let rowHeight: CGFloat = 62
    // Clears the zoom toolbar (top) and the legend (bottom), which overlay the canvas.
    private let topPadding: CGFloat = 60
    private let bottomPadding: CGFloat = 64
    private let centralX: CGFloat = 66
    private let groupBadgeX: CGFloat = 205
    private let groupBadgeWidth: CGFloat = 150
    private let portX: CGFloat = 385
    private let detailX: CGFloat = 595
    private let nodeWidth: CGFloat = 150
    private var detailNodeWidth: CGFloat { nodeWidth + 60 }

    private var ports: [PortInfo] { viewModel.filteredPorts }

    /// Same-PID ports (e.g. ControlCenter listening on both 5000 and 7000) are
    /// grouped so the graph can show "one process, several ports" instead of
    /// implying N unrelated services just because each has its own socket.
    private var groups: [PortGroup] {
        let grouped = Dictionary(grouping: ports, by: \.pid)
        return grouped.map { PortGroup(pid: $0.key, ports: $0.value.sorted { $0.port < $1.port }) }
            .sorted { ($0.ports.first?.port ?? 0) < ($1.ports.first?.port ?? 0) }
    }

    private var contentHeight: CGFloat { CGFloat(max(ports.count, 1)) * rowHeight + topPadding + bottomPadding }
    private var contentWidth: CGFloat { detailX + detailNodeWidth / 2 + 40 }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    Canvas { context, _ in
                        let centerPoint = CGPoint(x: centralX + 34, y: contentHeight / 2)
                        var row = 0
                        for group in groups {
                            let color = group.ports.first?.category.color ?? .gray
                            let groupStartRow = row
                            let groupRowCount = group.ports.count
                            let groupCenterY = (rowY(groupStartRow) + rowY(groupStartRow + groupRowCount - 1)) / 2

                            if groupRowCount > 1 {
                                let badgePoint = CGPoint(x: groupBadgeX, y: groupCenterY)
                                let badgeHalfWidth = groupBadgeWidth / 2
                                strokeCurve(&context, from: centerPoint, to: CGPoint(x: badgePoint.x - badgeHalfWidth, y: badgePoint.y), color: color)
                                for offset in 0..<groupRowCount {
                                    let y = rowY(groupStartRow + offset)
                                    strokeCurve(&context, from: CGPoint(x: badgePoint.x + badgeHalfWidth, y: badgePoint.y), to: CGPoint(x: portX - nodeWidth / 2, y: y), color: color)
                                }
                            } else {
                                let y = rowY(groupStartRow)
                                strokeCurve(&context, from: centerPoint, to: CGPoint(x: portX - nodeWidth / 2, y: y), color: color)
                            }

                            for offset in 0..<groupRowCount {
                                let y = rowY(groupStartRow + offset)
                                strokeCurve(&context, from: CGPoint(x: portX + nodeWidth / 2, y: y), to: CGPoint(x: detailX - detailNodeWidth / 2, y: y), color: color)
                            }
                            row += groupRowCount
                        }
                    }
                    .allowsHitTesting(false)

                    // Scroll anchor for "start at the top-left".
                    Color.clear.frame(width: 1, height: 1)
                        .id(Self.originID)
                        .position(x: 0.5, y: 0.5)

                    centralNode
                        .id(Self.centralNodeID)
                        .position(x: centralX, y: contentHeight / 2)

                    groupedNodes
                }
                // Scale the natural-size layout, then tell the ScrollView the resulting
                // *visual* footprint so its scrollable area matches what's actually zoomed in.
                .frame(width: contentWidth, height: contentHeight, alignment: .topLeading)
                .scaleEffect(effectiveZoom, anchor: .topLeading)
                .frame(width: contentWidth * effectiveZoom, height: contentHeight * effectiveZoom, alignment: .topLeading)
            }
            .gesture(
                MagnificationGesture()
                    .updating($pinchDelta) { value, state, _ in state = value }
                    .onEnded { value in zoom = clampedZoom(zoom * value) }
            )
            .onAppear { positionOnce(proxy) }
            .onChange(of: ports.count) { _ in positionOnce(proxy) }
            .overlay(alignment: .topTrailing) {
                toolbar(
                    resetAction: {
                        withAnimation { zoom = 1 }
                        proxy.scrollTo(Self.originID, anchor: .topLeading)
                    },
                    centerAction: { proxy.scrollTo(Self.centralNodeID, anchor: .center) }
                )
            }
            .overlay(alignment: .bottomLeading) { minimap }
            .overlay(alignment: .bottom) { legend }
        }
    }

    /// Open at the top-left once there's something to show; after that, leave the
    /// scroll position alone so ports starting/stopping never yanks the view around.
    private func positionOnce(_ proxy: ScrollViewProxy) {
        guard !hasPositioned, !ports.isEmpty else { return }
        hasPositioned = true
        DispatchQueue.main.async { proxy.scrollTo(Self.originID, anchor: .topLeading) }
    }

    @ViewBuilder
    private var groupedNodes: some View {
        ForEach(groups) { group in
            let startRow = rowOffset(of: group)
            if group.ports.count > 1, let first = group.ports.first {
                processBadge(processName: first.processName, pid: group.pid, count: group.ports.count, color: first.category.color)
                    .position(x: groupBadgeX, y: (rowY(startRow) + rowY(startRow + group.ports.count - 1)) / 2)
            }
            ForEach(Array(group.ports.enumerated()), id: \.element.id) { offset, info in
                let y = rowY(startRow + offset)
                portNode(info)
                    .position(x: portX, y: y)
                detailNode(info)
                    .position(x: detailX, y: y)
            }
        }
    }

    private func rowOffset(of target: PortGroup) -> Int {
        var row = 0
        for group in groups {
            if group.pid == target.pid { return row }
            row += group.ports.count
        }
        return row
    }

    private var effectiveZoom: CGFloat { clampedZoom(zoom * pinchDelta) }

    private func clampedZoom(_ value: CGFloat) -> CGFloat {
        min(max(value, 0.4), 2.5)
    }

    private func rowY(_ index: Int) -> CGFloat {
        rowHeight * CGFloat(index) + rowHeight / 2 + topPadding
    }

    private func strokeCurve(_ context: inout GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        var path = Path()
        path.move(to: from)
        let midX = (from.x + to.x) / 2
        path.addCurve(
            to: to,
            control1: CGPoint(x: midX, y: from.y),
            control2: CGPoint(x: midX, y: to.y)
        )
        context.stroke(path, with: .color(color.opacity(0.55)), lineWidth: 1.5)
    }

    private var centralNode: some View {
        VStack(spacing: 4) {
            Image(systemName: "server.rack")
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.blue))
            Text("localhost").font(.system(size: 11, weight: .semibold))
            Text("127.0.0.1").font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .frame(width: 100)
    }

    private func processBadge(processName: String, pid: Int32, count: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            ServiceIconView(processName: processName, size: 20)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            VStack(alignment: .leading, spacing: 0) {
                Text(processName).font(.system(size: 10, weight: .semibold)).lineLimit(1)
                Text(verbatim: "PID \(pid) · \(count) ports").font(.system(size: 8)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        // Fixed TOTAL width (matching groupBadgeWidth) so the Canvas fan-out lines,
        // computed from that same constant, always start exactly at this box's edge.
        .frame(width: groupBadgeWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.thinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(color.opacity(0.5), lineWidth: 1))
        )
        .help("\(processName) (PID \(pid)) is listening on \(count) ports")
    }

    private func portNode(_ info: PortInfo) -> some View {
        Button {
            viewModel.selectedPortID = info.id
        } label: {
            HStack(spacing: 8) {
                ServiceIconView(processName: info.processName, size: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: "\(info.port)").font(.system(size: 12, weight: .semibold))
                    Text(info.processName).font(.system(size: 9.5)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(width: nodeWidth)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .strokeBorder(viewModel.selectedPortID == info.id ? Color.accentColor : info.category.color.opacity(0.4), lineWidth: viewModel.selectedPortID == info.id ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func detailNode(_ info: PortInfo) -> some View {
        Button {
            viewModel.selectedPortID = info.id
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.fill").foregroundStyle(info.category.color)
                VStack(alignment: .leading, spacing: 1) {
                    Text(info.detectedLabel).font(.system(size: 11, weight: .medium)).lineLimit(2)
                    Text(info.protocolLabel).font(.system(size: 9)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(width: detailNodeWidth)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(.thinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(info.category.color.opacity(0.3), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }

    private func toolbar(resetAction: @escaping () -> Void, centerAction: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            toolbarButton("arrow.up.left.and.arrow.down.right", action: resetAction)
            toolbarButton("plus.magnifyingglass") { zoom = clampedZoom(zoom + 0.15) }
            toolbarButton("minus.magnifyingglass") { zoom = clampedZoom(zoom - 0.15) }
            toolbarButton("scope", action: centerAction)
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 8).fill(.thinMaterial))
        .padding(10)
    }

    private func toolbarButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage).frame(width: 22, height: 22)
        }
        .buttonStyle(.borderless)
    }

    /// A schematic of the real node layout (not the current scroll position): each dot
    /// sits where its node does on the canvas, scaled down to fit the box.
    private var minimap: some View {
        let boxWidth: CGFloat = 150
        let boxHeight: CGFloat = 90
        let inset: CGFloat = 10
        let xScale = (boxWidth - inset * 2) / contentWidth
        let yScale = (boxHeight - inset * 2) / contentHeight
        let orderedPorts = groups.flatMap(\.ports)

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6).fill(.thinMaterial)
            Circle()
                .fill(Color.blue)
                .frame(width: 6, height: 6)
                .position(x: inset + centralX * xScale, y: inset + contentHeight / 2 * yScale)
            ForEach(Array(orderedPorts.enumerated()), id: \.element.id) { index, info in
                Circle()
                    .fill(info.category.color)
                    .frame(width: 4, height: 4)
                    .position(x: inset + portX * xScale, y: inset + rowY(index) * yScale)
                Circle()
                    .fill(info.category.color.opacity(0.45))
                    .frame(width: 3, height: 3)
                    .position(x: inset + detailX * xScale, y: inset + rowY(index) * yScale)
            }
        }
        .frame(width: boxWidth, height: boxHeight)
        .padding(10)
    }

    private var legend: some View {
        HStack(spacing: 16) {
            ForEach(PortCategory.allCases, id: \.self) { category in
                HStack(spacing: 4) {
                    Circle().fill(category.color).frame(width: 7, height: 7)
                    Text(category.label).font(.system(size: 9.5, weight: .medium)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(.thinMaterial))
        .padding(.bottom, 10)
    }
}
