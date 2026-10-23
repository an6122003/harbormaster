import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var viewModel: PortListViewModel

    var body: some View {
        VStack(spacing: 4) {
            ForEach(SidebarSection.allCases) { section in
                Button {
                    viewModel.sidebarSection = section
                } label: {
                    VStack(spacing: 4) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: section.systemImage)
                                .font(.system(size: 17, weight: .medium))
                                .frame(width: 34, height: 34)
                                .background(
                                    RoundedRectangle(cornerRadius: 9)
                                        .fill(viewModel.sidebarSection == section ? Color.accentColor.opacity(0.18) : .clear)
                                )
                                .foregroundStyle(viewModel.sidebarSection == section ? Color.accentColor : Color.secondary)

                            if section == .alerts, !viewModel.alertPorts.isEmpty {
                                Text(verbatim: "\(viewModel.alertPorts.count)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(3)
                                    .background(Circle().fill(Color.red))
                                    .offset(x: 4, y: -2)
                            }
                        }
                        Text(section.rawValue)
                            .font(.system(size: 9.5))
                            .foregroundStyle(viewModel.sidebarSection == section ? Color.accentColor : Color.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer()

            VStack(spacing: 3) {
                HStack(spacing: 4) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text("Monitoring").font(.system(size: 8)).foregroundStyle(.secondary)
                }
                Text(verbatim: "\(viewModel.ports.count) ports").font(.system(size: 8)).foregroundStyle(.secondary)
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, 8)
        }
        .padding(.top, 16)
        .padding(.horizontal, 8)
        .frame(width: 76)
        .frame(maxHeight: .infinity)
        .background(.thinMaterial)
    }
}
