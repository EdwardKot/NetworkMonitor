import AppKit

class AppMetadataCache {
    static let shared = AppMetadataCache()
    
    // Key: PID
    private var cache: [Int32: (name: String, icon: NSImage?)] = [:]
    private let lock = NSLock()
    
    // Fallback icon
    private let defaultIcon: NSImage? = {
        let image = NSImage(systemSymbolName: "gear", accessibilityDescription: "Process")
        return image
    }()
    
    func getMetadata(for pid: Int32, defaultName: String) -> (name: String, icon: NSImage?) {
        lock.lock()
        defer { lock.unlock() }
        
        if let cached = cache[pid] {
            return cached
        }
        
        // Fetch fresh metadata
        var name = defaultName
        var icon = defaultIcon
        
        if let app = NSRunningApplication(processIdentifier: pid) {
            name = app.localizedName ?? defaultName
            icon = app.icon
        } else {
            // Try to find via workspace if it's not a running app (unlikely for active network but possible for background daemons)
            // For now, sticking to NSRunningApplication is safest for speed
        }
        
        cache[pid] = (name: name, icon: icon)
        return (name: name, icon: icon)
    }
    
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }
}
