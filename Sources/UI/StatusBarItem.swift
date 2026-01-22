import AppKit
import SwiftUI

class StatusBarItem: NSObject {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var dlLabel: NSTextField!
    private var ulLabel: NSTextField!
    
    init(popover: NSPopover) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.popover = popover
        super.init()
        
        setupView()
    }
    
    private func setupView() {
        guard let button = statusItem.button else { return }
        button.action = #selector(togglePopover(_:))
        button.target = self
        
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 70, height: 22))
        
        dlLabel = createLabel(frame: NSRect(x: 0, y: 11, width: 70, height: 11))
        ulLabel = createLabel(frame: NSRect(x: 0, y: 0, width: 70, height: 11))
        
        container.addSubview(dlLabel)
        container.addSubview(ulLabel)
        
        button.addSubview(container)
        button.frame = container.frame
    }
    
    private func createLabel(frame: NSRect) -> NSTextField {
        let label = NSTextField(frame: frame)
        label.isEditable = false
        label.isSelectable = false
        label.isBordered = false
        label.drawsBackground = false
        label.alignment = .left
        label.font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .semibold)
        return label
    }
    
    func updateTitle(download: String, upload: String) {
        // Adjust width based on text length
        let maxLen = max(download.count, upload.count)
        let width = CGFloat(max(55, maxLen * 6 + 5))
        
        DispatchQueue.main.async {
            self.dlLabel.stringValue = "↙ " + download
            self.ulLabel.stringValue = "↗ " + upload
            
            if self.popover.isShown {
                return
            }
            
            if self.statusItem.button?.frame.width != width {
                var frame = self.statusItem.button?.frame ?? .zero
                frame.size.width = width
                self.statusItem.button?.frame = frame
                self.dlLabel.frame.size.width = width
                self.ulLabel.frame.size.width = width
            }
        }
    }
    
    @objc func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else if let button = statusItem.button {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            DispatchQueue.main.async { [weak self] in
                self?.clampPopoverWindowToVisibleFrame()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
                self?.clampPopoverWindowToVisibleFrame()
            }
        }
    }
    
    private func clampPopoverWindowToVisibleFrame() {
        guard popover.isShown else { return }
        guard let popoverWindow = popover.contentViewController?.view.window else { return }
        let screen = statusItem.button?.window?.screen ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return }
        
        var frame = popoverWindow.frame
        let inset: CGFloat = 8
        
        let minX = visibleFrame.minX + inset
        let maxX = visibleFrame.maxX - frame.width - inset
        let minY = visibleFrame.minY + inset
        let maxY = visibleFrame.maxY - frame.height - inset
        
        if minX <= maxX {
            frame.origin.x = min(max(frame.origin.x, minX), maxX)
        }
        
        if minY <= maxY {
            frame.origin.y = min(max(frame.origin.y, minY), maxY)
        }
        
        popoverWindow.setFrame(frame, display: true)
    }
}
