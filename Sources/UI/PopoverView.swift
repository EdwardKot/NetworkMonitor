import SwiftUI

enum PopoverLayout {
    static let width: CGFloat = 320
    static let horizontalPadding: CGFloat = 14
    static let processRowHeight: CGFloat = 38
}

private enum PopoverDestination: Equatable {
    case dashboard
    case traffic(TrafficDetailType)
}

struct PopoverView: View {
    @ObservedObject var state: AppState
    let onSettings: () -> Void

    @AppStorage("processDisplayCount") private var processDisplayCount = 6
    @AppStorage("showProcessIcon") private var showProcessIcon = true
    @State private var destination: PopoverDestination = .dashboard

    private var visibleRowLimit: Int {
        max(3, min(6, processDisplayCount))
    }

    var body: some View {
        Group {
            switch destination {
            case .dashboard:
                dashboard
                    .transition(.opacity)
            case .traffic(let type):
                TrafficDetailView(type: type) {
                    withAnimation(.easeOut(duration: 0.14)) {
                        destination = .dashboard
                    }
                }
                .transition(.opacity)
            }
        }
        .frame(width: PopoverLayout.width)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var dashboard: some View {
        VStack(spacing: 0) {
            header

            ThroughputPanel(
                download: state.totalDownload,
                upload: state.totalUpload,
                downloadHistory: state.downloadHistory,
                uploadHistory: state.uploadHistory,
                onSelect: showTrafficDetail
            )
            .padding(.horizontal, PopoverLayout.horizontalPadding)
            .padding(.bottom, 14)

            Divider()

            ProcessListView(
                processes: state.processes,
                showIcon: showProcessIcon,
                visibleRowLimit: visibleRowLimit
            )
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Network Activity")
                .font(.headline)

            Spacer(minLength: 12)

            Menu {
                Button("Settings…", systemImage: "gearshape", action: onSettings)

                Divider()

                Button("Quit Network Monitor", systemImage: "power") {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More")
        }
        .padding(.horizontal, PopoverLayout.horizontalPadding)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private func showTrafficDetail(_ type: TrafficDetailType) {
        withAnimation(.easeOut(duration: 0.14)) {
            destination = .traffic(type)
        }
    }
}
