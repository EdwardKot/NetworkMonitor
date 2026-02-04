import Foundation
import AppKit

struct ProcessNetworkStats: Identifiable {
    let id: Int32
    let name: String
    var download: UInt64
    var upload: UInt64
    var icon: NSImage?
    var lastActiveTime: Date
}

struct ProcessTrafficRecord: Identifiable {
    let id: String
    let name: String
    var totalDownload: UInt64
    var totalUpload: UInt64
    var icon: NSImage?
    var firstSeen: Date
    var lastSeen: Date
}

class TrafficHistoryStore {
    static let shared = TrafficHistoryStore()
    
    private var records: [String: ProcessTrafficRecord] = [:]
    private let lock = NSLock()
    private let retentionPeriod: TimeInterval = 24 * 60 * 60
    
    func record(name: String, pid: Int32, download: UInt64, upload: UInt64, icon: NSImage?) {
        guard download > 0 || upload > 0 else { return }
        
        let key = name
        let now = Date()
        
        lock.lock()
        defer { lock.unlock() }
        
        if var existing = records[key] {
            existing.totalDownload += download
            existing.totalUpload += upload
            existing.lastSeen = now
            if icon != nil { existing.icon = icon }
            records[key] = existing
        } else {
            records[key] = ProcessTrafficRecord(
                id: key,
                name: name,
                totalDownload: download,
                totalUpload: upload,
                icon: icon,
                firstSeen: now,
                lastSeen: now
            )
        }
    }
    
    func getRecords(sortBy: TrafficSortType) -> [ProcessTrafficRecord] {
        lock.lock()
        let snapshot = records.values.map { $0 }
        lock.unlock()
        
        switch sortBy {
        case .download:
            return snapshot.sorted { $0.totalDownload > $1.totalDownload }
        case .upload:
            return snapshot.sorted { $0.totalUpload > $1.totalUpload }
        case .total:
            return snapshot.sorted { ($0.totalDownload + $0.totalUpload) > ($1.totalDownload + $1.totalUpload) }
        }
    }
    
    func cleanup() {
        let cutoff = Date().addingTimeInterval(-retentionPeriod)
        lock.lock()
        records = records.filter { $0.value.lastSeen > cutoff }
        lock.unlock()
    }
    
    func totalDownload() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return records.values.reduce(0) { $0 + $1.totalDownload }
    }
    
    func totalUpload() -> UInt64 {
        lock.lock()
        defer { lock.unlock() }
        return records.values.reduce(0) { $0 + $1.totalUpload }
    }
}

enum TrafficSortType {
    case download, upload, total
}

class ProcessMonitor {
    private var lastStats: [String: (rx: UInt64, tx: UInt64)] = [:]
    
    private let monitorQueue = DispatchQueue(label: "com.antigravity.nettop", qos: .utility)
    
    private var currentProcesses: [String: ProcessNetworkStats] = [:]
    private let lock = NSLock()
    
    private let cooldownDuration: TimeInterval = 8.0
    
    private var isUpdating = false
    private var lastCleanup = Date()
    private let cleanupInterval: TimeInterval = 60.0
    
    func fetchProcesses() -> [ProcessNetworkStats] {
        triggerUpdateIfNeeded()
        
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date()
        let activeProcesses = currentProcesses.values.filter { process in
            let isActive = process.download > 0 || process.upload > 0
            let withinCooldown = now.timeIntervalSince(process.lastActiveTime) < cooldownDuration
            return isActive || withinCooldown
        }
        
        return activeProcesses.sorted { lhs, rhs in
            let lhsActive = lhs.download > 0 || lhs.upload > 0
            let rhsActive = rhs.download > 0 || rhs.upload > 0
            
            if lhsActive && !rhsActive { return true }
            if !lhsActive && rhsActive { return false }
            
            let lhsTotal = lhs.download + lhs.upload
            let rhsTotal = rhs.download + rhs.upload
            return lhsTotal > rhsTotal
        }
    }
    
    private func triggerUpdateIfNeeded() {
        lock.lock()
        let shouldUpdate = !isUpdating
        if shouldUpdate { isUpdating = true }
        lock.unlock()
        
        guard shouldUpdate else { return }
        
        monitorQueue.async { [weak self] in
            self?.runNettop()
        }
    }
    
    private func runNettop() {
        let task = Process()
        task.launchPath = "/usr/bin/nettop"
        task.arguments = ["-L", "1", "-P", "-t", "external", "-J", "bytes_in,bytes_out"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()
            
            if let output = String(data: data, encoding: .utf8) {
                self.processOutput(output)
            }
        } catch {
            // Silently fail
        }
        
        lock.lock()
        isUpdating = false
        lock.unlock()
        
        periodicCleanupIfNeeded()
    }
    
    private func periodicCleanupIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastCleanup) > cleanupInterval else { return }
        lastCleanup = now
        
        lock.lock()
        let activeKeys = Set(currentProcesses.keys)
        lastStats = lastStats.filter { activeKeys.contains($0.key) }
        lock.unlock()
        
        TrafficHistoryStore.shared.cleanup()
        AppMetadataCache.shared.pruneStaleEntries()
    }
    
    private func processOutput(_ output: String) {
        let lines = output.components(separatedBy: .newlines)
        let now = Date()
        
        // Track which processes we've seen in this update
        var seenKeys = Set<String>()
        
        for line in lines {
            let parts = line.components(separatedBy: ",")
            if parts.count >= 3 {
                let nameWithPID = parts[0]
                if nameWithPID.isEmpty { continue }
                
                if let rx = UInt64(parts[1]), let tx = UInt64(parts[2]) {
                    self.processLine(nameWithPID: nameWithPID, rx: rx, tx: tx, now: now, seenKeys: &seenKeys)
                }
            }
        }
        
        // Update speeds to 0 for processes not seen in this update (they're idle)
        lock.lock()
        for key in currentProcesses.keys {
            if !seenKeys.contains(key) {
                currentProcesses[key]?.download = 0
                currentProcesses[key]?.upload = 0
            }
        }
        
        // Cleanup: Remove processes that have been idle longer than cooldown
        let staleThreshold = now.addingTimeInterval(-cooldownDuration)
        currentProcesses = currentProcesses.filter { _, process in
            let isActive = process.download > 0 || process.upload > 0
            return isActive || process.lastActiveTime > staleThreshold
        }
        lock.unlock()
    }
    
    private func processLine(nameWithPID: String, rx: UInt64, tx: UInt64, now: Date, seenKeys: inout Set<String>) {
        let components = nameWithPID.components(separatedBy: ".")
        guard components.count >= 2,
              let pid = Int32(components.last!) else { return }
        
        let rawName = components.dropLast().joined(separator: ".")
        let key = "\(rawName).\(pid)"
        seenKeys.insert(key)
        
        var dlSpeed: UInt64 = 0
        var ulSpeed: UInt64 = 0
        
        if let last = lastStats[key] {
            if rx >= last.rx { dlSpeed = rx - last.rx }
            if tx >= last.tx { ulSpeed = tx - last.tx }
        }
        
        lastStats[key] = (rx: rx, tx: tx)
        
        let metadata = AppMetadataCache.shared.getMetadata(for: pid, defaultName: rawName)
        
        lock.lock()
        if dlSpeed > 0 || ulSpeed > 0 {
            currentProcesses[key] = ProcessNetworkStats(
                id: pid,
                name: metadata.name,
                download: dlSpeed,
                upload: ulSpeed,
                icon: metadata.icon,
                lastActiveTime: now
            )
            TrafficHistoryStore.shared.record(
                name: metadata.name,
                pid: pid,
                download: dlSpeed,
                upload: ulSpeed,
                icon: metadata.icon
            )
        } else if var existing = currentProcesses[key] {
            existing.download = 0
            existing.upload = 0
            currentProcesses[key] = existing
        }
        lock.unlock()
    }
}
