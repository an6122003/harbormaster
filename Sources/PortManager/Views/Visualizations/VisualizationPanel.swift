import SwiftUI

struct VisualizationPanel: View {
    @EnvironmentObject var viewModel: PortListViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("", selection: $viewModel.mapViewMode) {
                    ForEach(MapViewMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 420)
                Spacer()
            }
            .padding(12)

            Divider()

            Group {
                switch viewModel.mapViewMode {
                case .networkMap: NetworkMapView()
                case .processTree: ProcessTreeView()
                case .connectionFlow: ConnectionFlowView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
