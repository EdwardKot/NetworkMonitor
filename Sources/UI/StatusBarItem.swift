import AppKit
import SwiftUI

class StatusBarItem: NSObject {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var lastWidth: CGFloat = 0
    private let font: NSFont = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .semibold)
    private let horizontalPadding: CGFloat = 4
    private let verticalPadding: CGFloat = 1
    private let minWidth: CGFloat = 55
    
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
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
    }
    
    func updateTitle(download: String, upload: String) {
        assert(Thread.isMainThread, "status bar updates must be on the main thread")
        let dlText = "↙ " + download
        let ulText = "↗ " + upload

        let render = renderStatusImage(download: dlText, upload: ulText)
        statusItem.button?.image = render.image

        if render.width != lastWidth {
            lastWidth = render.width
            statusItem.length = render.width
        }
    }
    
    private func renderStatusImage(download: String, upload: String) -> (image: NSImage, width: CGFloat) {
        let dlAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        let ulAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        
        let dlSize = (download as NSString).size(withAttributes: dlAttributes)
        let ulSize = (upload as NSString).size(withAttributes: ulAttributes)
        let textWidth = max(dlSize.width, ulSize.width)
        let width = max(minWidth, ceil(textWidth + horizontalPadding * 2))
        let height: CGFloat = 22
        
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
        
        let lineHeight = max(dlSize.height, ulSize.height)
        let topY = height - lineHeight - verticalPadding
        let bottomY = verticalPadding
        
        (download as NSString).draw(at: CGPoint(x: horizontalPadding, y: topY), withAttributes: dlAttributes)
        (upload as NSString).draw(at: CGPoint(x: horizontalPadding, y: bottomY), withAttributes: ulAttributes)
        image.unlockFocus()
        image.isTemplate = false
        
        return (image: image, width: width)
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
