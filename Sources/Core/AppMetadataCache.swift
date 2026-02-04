import AppKit

class AppMetadataCache {
    static let shared = AppMetadataCache()
    
    private var cache: [Int32: (name: String, icon: NSImage?, lastAccess: Date)] = [:]
    private let lock = NSLock()
    
    private let defaultIcon: NSImage? = {
        let image = NSImage(systemSymbolName: "gear", accessibilityDescription: "Process")
        return image
    }()
    
    func getMetadata(for pid: Int32, defaultName: String) -> (name: String, icon: NSImage?) {
        lock.lock()
        defer { lock.unlock() }
        
        if let cached = cache[pid] {
            cache[pid] = (name: cached.name, icon: cached.icon, lastAccess: Date())
            return (name: cached.name, icon: cached.icon)
        }
        
        var name = defaultName
        var icon = defaultIcon
        
        if let app = NSRunningApplication(processIdentifier: pid) {
            name = app.localizedName ?? defaultName
            icon = app.icon
        }
        
        cache[pid] = (name: name, icon: icon, lastAccess: Date())
        return (name: name, icon: icon)
    }
    
    func pruneStaleEntries() {
        let cutoff = Date().addingTimeInterval(-3600)
        lock.lock()
        cache = cache.filter { $0.value.lastAccess > cutoff }
        lock.unlock()
    }
    
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        cache.removeAll()
    }
}
