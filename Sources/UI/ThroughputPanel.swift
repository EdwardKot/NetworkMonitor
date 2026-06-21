import SwiftUI

struct ThroughputPanel: View {
    let download: UInt64
    let upload: UInt64
    let downloadHistory: [CGFloat]
    let uploadHistory: [CGFloat]
    let onSelect: (TrafficDetailType) -> Void

    var body: some View {
        HStack(spacing: 0) {
            SpeedMetricView(
                label: "Download",
                value: download,
                tint: .green,
                icon: "arrow.down",
                history: downloadHistory
            ) {
                onSelect(.download)
            }

            Divider()
                .padding(.vertical, 12)

            SpeedMetricView(
                label: "Upload",
                value: upload,
                tint: .blue,
                icon: "arrow.up",
                history: uploadHistory
            ) {
                onSelect(.upload)
            }
        }
        .frame(height: 108)
        .background {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(.quinary)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 0.5)
        }
    }
}

private struct SpeedMetricView: View {
    let label: String
    let value: UInt64
    let tint: Color
    let icon: String
    let history: [CGFloat]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                Label(label, systemImage: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.monochrome)

                Text(Units.bytes(value))
                    .font(.system(.title2, design: .default, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .contentTransition(.numericText(value: Double(value)))
                    .animation(.snappy, value: value)
                    .padding(.top, 6)

                Spacer(minLength: 6)

                Sparkline(data: history, color: tint)
                    .frame(height: 26)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(MetricButtonStyle(tint: tint))
        .help("Show \(label.lowercased()) traffic history")
        .accessibilityLabel("\(label), \(Units.bytes(value))")
    }
}

private struct MetricButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? tint.opacity(0.08) : .clear)
            .contentShape(Rectangle())
    }
}
