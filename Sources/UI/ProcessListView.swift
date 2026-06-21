import AppKit
import SwiftUI

struct ProcessListView: View {
    let processes: [ProcessNetworkStats]
    let showIcon: Bool
    let visibleRowLimit: Int

    private var listHeight: CGFloat {
        let visibleRows = max(1, min(processes.count, visibleRowLimit))
        return CGFloat(visibleRows) * PopoverLayout.processRowHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Top Processes")
                    .font(.subheadline.weight(.semibold))

                Spacer()

                if !processes.isEmpty {
                    Text("\(processes.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 6)

            if processes.isEmpty {
                EmptyProcessState()
            } else {
                ScrollView(.vertical, showsIndicators: processes.count > visibleRowLimit) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(processes.enumerated()), id: \.element.id) { index, process in
                            ProcessRow(process: process, showIcon: showIcon)

                            if index < processes.count - 1 {
                                Divider()
                                    .padding(.leading, showIcon ? 36 : 8)
                            }
                        }
                    }
                }
                .scrollDisabled(processes.count <= visibleRowLimit)
                .frame(height: listHeight)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 9)
    }
}

private struct EmptyProcessState: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.path")
                .foregroundStyle(.tertiary)

            Text("Waiting for active traffic")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 46)
    }
}

private struct ProcessRow: View {
    let process: ProcessNetworkStats
    let showIcon: Bool

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 9) {
            if showIcon {
                ProcessIcon(image: process.icon)
            }

            Text(process.name)
                .font(.system(size: 12.5, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 6)

            HStack(spacing: 8) {
                RateLabel(value: process.download, icon: "arrow.down", tint: .green)
                RateLabel(value: process.upload, icon: "arrow.up", tint: .blue)
            }
        }
        .padding(.horizontal, 7)
        .frame(height: PopoverLayout.processRowHeight)
        .background {
            if isHovering {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(.quinary)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Copy Name", systemImage: "doc.on.doc") {
                copyToPasteboard(process.name)
            }

            Button("Copy PID", systemImage: "number") {
                copyToPasteboard(String(process.id))
            }

            Divider()

            Button("Quit Process", systemImage: "xmark.circle", role: .destructive) {
                kill(process.id, SIGTERM)
            }
        }
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

private struct ProcessIcon: View {
    let image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .antialiased(true)
            } else {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .symbolRenderingMode(.monochrome)
            }
        }
        .frame(width: 18, height: 18)
    }
}

private struct RateLabel: View {
    let value: UInt64
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(tint)

            Text(Units.bytes(value))
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 10.5, weight: .medium))
        .monospacedDigit()
        .frame(width: 62, alignment: .trailing)
    }
}
