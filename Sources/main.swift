import AppKit
import SwiftUI

class AppState: ObservableObject {
    @Published var totalDownload: UInt64 = 0
    @Published var totalUpload: UInt64 = 0
    @Published var processes: [ProcessNetworkStats] = []
    @Published var downloadHistory: [CGFloat] = Array(repeating: 0, count: 20)
    @Published var uploadHistory: [CGFloat] = Array(repeating: 0, count: 20)
}

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var statusBar: StatusBarItem?
    var popover = NSPopover()
    let reader = NetworkReader()
    let processMonitor = ProcessMonitor()
    private var totalTimer: Timer?
    private var processTimer: Timer?
    private var isPopoverVisible = false
    
    let state = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // Clean up orphaned launchd registrations from old bundle identifiers
        LaunchAtLoginManager.cleanOrphanedRegistrations()
        
        let contentView = PopoverView(state: state, onSettings: { [weak self] in self?.openSettings() })
        popover.contentViewController = NSHostingController(rootView: contentView)
        popover.contentSize = NSSize(width: 300, height: 480)  // Must match PopoverView.frame
        popover.behavior = .transient
        popover.delegate = self
        
        statusBar = StatusBarItem(popover: popover)
        
        startTotalTimer()
    }
    
    var settingsWindow: NSWindow?
    let settings = SettingsManager()

    func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(settings: settings, onUpdateIntervalChanged: { [weak self] _ in
                self?.startTotalTimer()
            }, onProcessIntervalChanged: { [weak self] _ in
                if self?.isPopoverVisible == true {
                    self?.startProcessTimer()
                }
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
    
    func startTotalTimer() {
        let interval = max(0.5, settings.updateInterval)
        if interval != settings.updateInterval {
            settings.updateInterval = interval
        }
        totalTimer?.invalidate()
        totalTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateTotals()
        }
        totalTimer?.tolerance = min(0.25, interval * 0.2)
    }
    
    func startProcessTimer() {
        let interval = max(1.0, settings.processUpdateInterval)
        if interval != settings.processUpdateInterval {
            settings.processUpdateInterval = interval
        }
        processTimer?.invalidate()
        processTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateProcesses()
        }
        processTimer?.tolerance = min(0.5, interval * 0.2)
    }
    
    func stopProcessTimer() {
        processTimer?.invalidate()
        processTimer = nil
    }
    
    func updateTotals() {
        let stats = reader.read()
        let dlStr = Units.bytes(stats.download)
        let ulStr = Units.bytes(stats.upload)

        updateTotals(stats: stats, dlStr: dlStr, ulStr: ulStr)
    }

    private var lastStatusDlStr: String = ""
    private var lastStatusUlStr: String = ""

    private func updateTotals(stats: NetworkStats, dlStr: String, ulStr: String) {
        // Skip main-thread dispatch and rendering if status bar text unchanged
        guard dlStr != lastStatusDlStr || ulStr != lastStatusUlStr else { return }
        lastStatusDlStr = dlStr
        lastStatusUlStr = ulStr

        let applyUpdates = { [weak self] in
            guard let self = self else { return }
            if self.isPopoverVisible {
                self.state.totalDownload = stats.download
                self.state.totalUpload = stats.upload

                self.state.downloadHistory.append(CGFloat(stats.download))
                self.state.downloadHistory.removeFirst()
                self.state.uploadHistory.append(CGFloat(stats.upload))
                self.state.uploadHistory.removeFirst()
            }

            self.statusBar?.updateTitle(
                download: dlStr,
                upload: ulStr
            )
        }

        if Thread.isMainThread {
            applyUpdates()
        } else {
            DispatchQueue.main.async(execute: applyUpdates)
        }
    }
    
    func updateProcesses() {
        guard isPopoverVisible else { return }
        let procStats = processMonitor.fetchProcesses()
        let applyUpdates = {
            if self.isPopoverVisible {
                self.state.processes = procStats
            }
        }
        if Thread.isMainThread {
            applyUpdates()
        } else {
            DispatchQueue.main.async(execute: applyUpdates)
        }
    }
    
    func popoverWillShow(_ notification: Notification) {
        isPopoverVisible = true
        startProcessTimer()
        updateProcesses()
    }
    
    func popoverDidClose(_ notification: Notification) {
        isPopoverVisible = false
        stopProcessTimer()
    }
}

// Global entry point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
