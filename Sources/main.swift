import AppKit
import SwiftUI

class AppState: ObservableObject {
    @Published var totalDownload: UInt64 = 0
    @Published var totalUpload: UInt64 = 0
    @Published var processes: [ProcessNetworkStats] = []
    @Published var downloadHistory: [CGFloat] = Array(repeating: 0, count: 20)
    @Published var uploadHistory: [CGFloat] = Array(repeating: 0, count: 20)
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBar: StatusBarItem?
    var popover = NSPopover()
    let reader = NetworkReader()
    let processMonitor = ProcessMonitor()
    var timer: Timer?
    
    let state = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        
        let contentView = PopoverView(state: state, onSettings: { [weak self] in self?.openSettings() })
        popover.contentViewController = NSHostingController(rootView: contentView)
        popover.contentSize = NSSize(width: 300, height: 480)  // Must match PopoverView.frame
        popover.behavior = .transient
        
        statusBar = StatusBarItem(popover: popover)
        
        startTimer()
    }
    
    var settingsWindow: NSWindow?
    let settings = SettingsManager()

    func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(settings: settings, onUpdateIntervalChanged: { [weak self] _ in
                self?.startTimer()
            })
            let controller = NSHostingController(rootView: view)
            settingsWindow = NSWindow(contentViewController: controller)
            settingsWindow?.title = "Settings"
            settingsWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            settingsWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: settings.updateInterval, repeats: true) { [weak self] _ in
            self?.update()
        }
    }
    
    func update() {
        let stats = reader.read()
        let procStats = processMonitor.fetchProcesses()
        
        DispatchQueue.main.async {
            self.state.totalDownload = stats.download
            self.state.totalUpload = stats.upload
            self.state.processes = procStats
            
            self.state.downloadHistory.append(CGFloat(stats.download))
            self.state.downloadHistory.removeFirst()
            self.state.uploadHistory.append(CGFloat(stats.upload))
            self.state.uploadHistory.removeFirst()
            
            self.statusBar?.updateTitle(
                download: Units.bytes(stats.download),
                upload: Units.bytes(stats.upload)
            )
        }
    }
}

// Global entry point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
