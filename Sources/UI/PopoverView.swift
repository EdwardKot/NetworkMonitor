import SwiftUI

struct ProcessRow: View {
    let process: ProcessNetworkStats
    let showIcon: Bool
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            if showIcon {
                Group {
                    if let icon = process.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .antialiased(true)
                    } else {
                        Image(systemName: "app.fill")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: 16))
                    }
                }
                .frame(width: 24, height: 24)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(process.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text(verbatim: "\(process.id)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.green.gradient)
                    Text(Units.bytes(process.download))
                }
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.blue.gradient)
                    Text(Units.bytes(process.upload))
                }
            }
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background {
            if isHovering {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.quinary)
            }
        }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(process.name, forType: .string)
            } label: {
                Text("Copy Name")
            }
            
            Divider()
            
            Button(role: .destructive) {
                kill(process.id, SIGTERM)
            } label: {
                Text("Kill Process")
            }
        }
    }
}

struct PopoverView: View {
    @ObservedObject var state: AppState
    var onSettings: () -> Void
    @AppStorage("processDisplayCount") private var processDisplayCount: Int = 10
    @AppStorage("showProcessIcon") private var showProcessIcon: Bool = true
    
    private let rowHeight: CGFloat = 44
    
    private var clampedProcessDisplayCount: Int {
        max(5, min(10, processDisplayCount))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header Section
            VStack(spacing: 16) {
                HStack {
                    Text("Network Activity")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 12) {
                    SpeedMetric(
                        label: "Download",
                        value: state.totalDownload,
                        tint: .green,
                        icon: "arrow.down.circle.fill",
                        history: state.downloadHistory
                    )
                    
                    SpeedMetric(
                        label: "Upload",
                        value: state.totalUpload,
                        tint: .blue,
                        icon: "arrow.up.circle.fill",
                        history: state.uploadHistory
                    )
                }
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.05))
                    .stroke(.white.opacity(0.1), lineWidth: 0.5)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Process List Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Top Processes")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 20)
                
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(state.processes) { process in
                            ProcessRow(process: process, showIcon: showProcessIcon)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(height: CGFloat(clampedProcessDisplayCount) * rowHeight)
            }
            
            Divider()
                .padding(.horizontal, 16)
            
            // Footer
            HStack {
                Button(action: onSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .onHover { isHovering in
                    if isHovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                
                Spacer()
                
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Text("Quit")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .onHover { isHovering in
                    if isHovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 320)
        .background(.regularMaterial)
    }
}

struct SpeedMetric: View {
    let label: String
    let value: UInt64
    let tint: Color
    let icon: String
    let history: [CGFloat]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(tint.gradient)
                    .font(.system(size: 14))
                
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            
            Spacer()
            
            Text(Units.bytes(value))
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText(value: Double(value)))
                .animation(.snappy, value: value)
            
            Spacer()
            
            Sparkline(data: history, color: tint)
                .frame(height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .frame(height: 100)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.black.opacity(0.1))
        }
    }
}
