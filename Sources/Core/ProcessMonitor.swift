import Foundation
import AppKit

struct ProcessNetworkStats: Identifiable {
    let id: Int32 // PID
    let name: String
    var download: UInt64
    var upload: UInt64
    var icon: NSImage?
    var lastActiveTime: Date  // NEW: Track when process was last active
}

class ProcessMonitor {
    private var lastStats: [String: (rx: UInt64, tx: UInt64)] = [:]
    
    // Serial queue for running nettop in the background
    private let monitorQueue = DispatchQueue(label: "com.antigravity.nettop", qos: .utility)
    
    // Cache for latest results to serve UI immediately
    private var currentProcesses: [String: ProcessNetworkStats] = [:]  // Key by name.pid
    private let lock = NSLock()
    
    // Cooldown: Keep processes visible for this duration after activity stops
    private let cooldownDuration: TimeInterval = 8.0  // seconds
    
    func fetchProcesses() -> [ProcessNetworkStats] {
        // Trigger background update
        updateStatsAsync()
        
        lock.lock()
        defer { lock.unlock() }
        
        // Filter out stale processes and sort by activity
        let now = Date()
        let activeProcesses = currentProcesses.values.filter { process in
            // Keep if: has activity OR within cooldown period
            let isActive = process.download > 0 || process.upload > 0
            let withinCooldown = now.timeIntervalSince(process.lastActiveTime) < cooldownDuration
            return isActive || withinCooldown
        }
        
        // Sort: Active processes first (by download), then idle ones
        return activeProcesses.sorted { lhs, rhs in
            let lhsActive = lhs.download > 0 || lhs.upload > 0
            let rhsActive = rhs.download > 0 || rhs.upload > 0
            
            if lhsActive && !rhsActive { return true }
            if !lhsActive && rhsActive { return false }
            
            // Both active or both idle - sort by download speed
            if lhs.download != rhs.download {
                return lhs.download > rhs.download
            }
            return lhs.upload > rhs.upload
        }
    }
    
    private func updateStatsAsync() {
        monitorQueue.async { [weak self] in
            guard let self = self else { return }
            
            let task = Process()
            task.launchPath = "/usr/bin/nettop"
            task.arguments = ["-L", "1", "-P", "-t", "external", "-J", "bytes_in,bytes_out"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            
            do {
                try task.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                task.waitUntilExit()
                
                if let output = String(data: data, encoding: .utf8) {
                    self.processOutput(output)
                }
            } catch {
                print("Error running nettop: \(error)")
            }
        }
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
            // Process is active - update or create with current timestamp
            currentProcesses[key] = ProcessNetworkStats(
                id: pid,
                name: metadata.name,
                download: dlSpeed,
                upload: ulSpeed,
                icon: metadata.icon,
                lastActiveTime: now
            )
        } else if var existing = currentProcesses[key] {
            // Process exists but is now idle - update speeds but keep old timestamp
            existing.download = 0
            existing.upload = 0
            currentProcesses[key] = existing
        }
        lock.unlock()
    }
}
