import SwiftUI

enum DisplayStyle: String, CaseIterable, Identifiable {
    case iconOnly = "Icon Only"
    case textOnly = "Text Only"
    case both = "Icon + Text"
    
    var id: String { self.rawValue }
}

class SettingsManager: ObservableObject {
    @AppStorage("updateInterval") var updateInterval: Double = 1.0
    @AppStorage("displayStyle") var displayStyle: DisplayStyle = .both
    @AppStorage("showProcessIcon") var showProcessIcon: Bool = true
    @AppStorage("processDisplayCount") var processDisplayCount: Int = 10
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false
}

struct SettingsView: View {
    @ObservedObject var settings: SettingsManager
    var onUpdateIntervalChanged: (Double) -> Void
    @State private var launchAtLoginError: String?
    @State private var isApplyingLaunchAtLoginChange: Bool = false
    
    var body: some View {
        Form {
            Section(header: Text("General")) {
                Slider(value: $settings.updateInterval, in: 0.5...5.0, step: 0.5) {
                    Text("Update Interval: \(settings.updateInterval, specifier: "%.1f")s")
                }
                .onChange(of: settings.updateInterval) { _, newValue in
                    onUpdateIntervalChanged(newValue)
                }
                
                Picker("Display Style", selection: $settings.displayStyle) {
                    ForEach(DisplayStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
            }
            
            Section(header: Text("Process List")) {
                Toggle("Show Process Icons", isOn: $settings.showProcessIcon)
                
                Stepper(value: $settings.processDisplayCount, in: 5...10, step: 1) {
                    Text("Visible Processes: \(settings.processDisplayCount)")
                }
            }
            
            Section(header: Text("Startup")) {
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { _, newValue in
                        guard !isApplyingLaunchAtLoginChange else { return }
                        isApplyingLaunchAtLoginChange = true
                        defer { isApplyingLaunchAtLoginChange = false }
                        
                        do {
                            try LaunchAtLoginManager.setEnabled(newValue)
                            launchAtLoginError = nil
                        } catch {
                            settings.launchAtLogin.toggle()
                            launchAtLoginError = error.localizedDescription
                        }
                    }
                
                Text("Starts the app automatically after you sign in. Works best when the app is placed in /Applications.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.caption)
                        .foregroundColor(.red)
                        .textSelection(.enabled)
                }
            }
            
            Section {
                Button("Quit Application") {
                    NSApplication.shared.terminate(nil)
                }
                .foregroundColor(.red)
            }
        }
        .padding()
        .frame(width: 420, height: 360)
        .onAppear {
            settings.processDisplayCount = max(5, min(10, settings.processDisplayCount))
            settings.launchAtLogin = LaunchAtLoginManager.isEnabled()
        }
    }
}
