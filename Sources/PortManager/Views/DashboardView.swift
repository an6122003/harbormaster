import SwiftUI

/// The three-column layout from the mockup: port list, network visualization,
/// and an optional detail panel for the selected port. Used by both the
/// Overview and Ports sidebar sections.
struct DashboardView: View {
    @EnvironmentObject var viewModel: PortListViewModel
    var showVisualization: Bool = true

    @State private var listWidth: CGFloat = 440
    @State private var detailWidth: CGFloat = 330

    var body: some View {
        HStack(spacing: 0) {
            PortsListPanel()
                .frame(width: showVisualization ? listWidth : nil)
                .frame(maxWidth: showVisualization ? nil : .infinity)

            if showVisualization {
                ResizableDivider(width: $listWidth, minWidth: 300, maxWidth: 640)

                VisualizationPanel()
                    .frame(minWidth: 220, maxWidth: .infinity, maxHeight: .infinity)

                if let selected = viewModel.selectedPort {
                    ResizableDivider(width: $detailWidth, minWidth: 280, maxWidth: 520, invert: true)
                    PortDetailPanel(info: selected)
                        .frame(width: detailWidth)
                }
            }
        }
    }
}
