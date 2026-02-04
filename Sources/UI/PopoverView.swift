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
    @State private var showingTrafficDetail: TrafficDetailType? = nil
    @State private var selectedAnchor: CGPoint = .zero
    
    private let rowHeight: CGFloat = 44
    
    private var clampedProcessDisplayCount: Int {
        max(5, min(10, processDisplayCount))
    }
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 16) {
                HStack {
                    Text("Network Activity")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                
                HStack(spacing: 12) {
                    SpeedMetric(
                        label: "Download",
                        value: state.totalDownload,
                        tint: .green,
                        icon: "arrow.down.circle.fill",
                        history: state.downloadHistory,
                        showingDetail: Binding(
                            get: { showingTrafficDetail == .download },
                            set: { if $0 { showingTrafficDetail = .download } else { showingTrafficDetail = nil } }
                        )
                    )
                    
                    SpeedMetric(
                        label: "Upload",
                        value: state.totalUpload,
                        tint: .blue,
                        icon: "arrow.up.circle.fill",
                        history: state.uploadHistory,
                        showingDetail: Binding(
                            get: { showingTrafficDetail == .upload },
                            set: { if $0 { showingTrafficDetail = .upload } else { showingTrafficDetail = nil } }
                        )
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

enum TrafficDetailType: Equatable {
    case download, upload
}

struct TrafficDetailView: View {
    let type: TrafficDetailType
    @Environment(\.dismiss) private var dismiss
    @State private var records: [ProcessTrafficRecord] = []
    
    private var title: String {
        type == .download ? "Download Traffic (24h)" : "Upload Traffic (24h)"
    }
    
    private var tint: Color {
        type == .download ? .green : .blue
    }
    
    private var totalTraffic: UInt64 {
        type == .download
            ? TrafficHistoryStore.shared.totalDownload()
            : TrafficHistoryStore.shared.totalUpload()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                    Text("Total: \(Units.bytesTotal(totalTraffic))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(16)
            
            Divider()
            
            if records.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No traffic recorded yet")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(records) { record in
                            TrafficRecordRow(record: record, type: type, tint: tint)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(width: 340, height: 400)
        .background(.regularMaterial)
        .onAppear {
            let sortType: TrafficSortType = type == .download ? .download : .upload
            records = TrafficHistoryStore.shared.getRecords(sortBy: sortType)
        }
    }
}

struct TrafficRecordRow: View {
    let record: ProcessTrafficRecord
    let type: TrafficDetailType
    let tint: Color
    @State private var isHovering = false
    
    private var trafficValue: UInt64 {
        type == .download ? record.totalDownload : record.totalUpload
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let icon = record.icon {
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
            
            Text(record.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            Spacer()
            
            Text(Units.bytesTotal(trafficValue))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(tint)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background {
            if isHovering {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.quinary)
            }
        }
        .onHover { isHovering = $0 }
    }
}

struct SpeedMetric: View {
    let label: String
    let value: UInt64
    let tint: Color
    let icon: String
    let history: [CGFloat]
    @Binding var showingDetail: Bool
    
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
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetail = true
        }
        .popover(isPresented: $showingDetail) {
            TrafficDetailView(type: label == "Download" ? .download : .upload)
        }
        .onHover { isHovering in
            if isHovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}
