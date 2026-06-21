import SwiftUI

enum TrafficDetailType: Equatable {
    case download
    case upload

    var title: String {
        self == .download ? "Download History" : "Upload History"
    }

    var tint: Color {
        self == .download ? .green : .blue
    }
}

struct TrafficDetailView: View {
    let type: TrafficDetailType
    let onBack: () -> Void

    @State private var records: [ProcessTrafficRecord] = []

    private var totalTraffic: UInt64 {
        type == .download
            ? TrafficHistoryStore.shared.totalDownload()
            : TrafficHistoryStore.shared.totalUpload()
    }

    private var listHeight: CGFloat {
        CGFloat(max(1, min(records.count, 7))) * 40
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if records.isEmpty {
                ContentUnavailableView(
                    "No Traffic Yet",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Per-process history appears after network activity is recorded.")
                )
                .frame(height: 150)
            } else {
                ScrollView(.vertical, showsIndicators: records.count > 7) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                            TrafficRecordRow(record: record, type: type)

                            if index < records.count - 1 {
                                Divider()
                                    .padding(.leading, 41)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .scrollDisabled(records.count <= 7)
                .frame(height: listHeight)
                .padding(.vertical, 5)
            }
        }
        .onAppear(perform: loadRecords)
    }

    private var header: some View {
        HStack(spacing: 9) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Back")

            VStack(alignment: .leading, spacing: 2) {
                Text(type.title)
                    .font(.headline)

                Text("24 hours · \(Units.bytesTotal(totalTraffic))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
    }

    private func loadRecords() {
        let sortType: TrafficSortType = type == .download ? .download : .upload
        records = TrafficHistoryStore.shared.getRecords(sortBy: sortType)
    }
}

private struct TrafficRecordRow: View {
    let record: ProcessTrafficRecord
    let type: TrafficDetailType

    @State private var isHovering = false

    private var trafficValue: UInt64 {
        type == .download ? record.totalDownload : record.totalUpload
    }

    var body: some View {
        HStack(spacing: 9) {
            Group {
                if let icon = record.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .antialiased(true)
                } else {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 18, height: 18)

            Text(record.name)
                .font(.system(size: 12.5, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            Text(Units.bytesTotal(trafficValue))
                .font(.caption.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(type.tint)
        }
        .padding(.horizontal, 7)
        .frame(height: 40)
        .background {
            if isHovering {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(.quinary)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}
