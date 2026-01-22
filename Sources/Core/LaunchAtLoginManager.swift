import Foundation

enum LaunchAtLoginManager {
    private static var label: String {
        let base = Bundle.main.bundleIdentifier?.replacingOccurrences(of: " ", with: "") ?? "com.antigravity.NetworkMonitor"
        return "\(base).launchAtLogin"
    }
    
    private static var plistURL: URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
        return dir.appendingPathComponent("\(label).plist", isDirectory: false)
    }
    
    static func isEnabled() -> Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }
    
    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try installAndLoad()
        } else {
            try unloadAndRemove()
        }
    }
    
    private static func installAndLoad() throws {
        guard let executableURL = Bundle.main.executableURL else {
            throw NSError(domain: "LaunchAtLogin", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not resolve executable path."])
        }
        
        let agentsDir = plistURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: agentsDir, withIntermediateDirectories: true)
        
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executableURL.path],
            "RunAtLoad": true,
            "KeepAlive": false,
            "ProcessType": "Interactive"
        ]
        
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL, options: [.atomic])
        
        do {
            try bootstrap()
        } catch {
            _ = try? bootout()
            try bootstrap()
        }
    }
    
    private static func unloadAndRemove() throws {
        _ = try? bootout()
        if FileManager.default.fileExists(atPath: plistURL.path) {
            try FileManager.default.removeItem(at: plistURL)
        }
    }
    
    private static func bootstrap() throws {
        let domain = "gui/\(getuid())"
        try runLaunchctl(arguments: ["bootstrap", domain, plistURL.path])
    }
    
    @discardableResult
    private static func bootout() throws -> Int32 {
        let domain = "gui/\(getuid())"
        return try runLaunchctl(arguments: ["bootout", domain, plistURL.path])
    }
    
    @discardableResult
    private static func runLaunchctl(arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        
        try process.run()
        process.waitUntilExit()
        
        let exitCode = process.terminationStatus
        if exitCode != 0 {
            let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let msg = err.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NSError(domain: "LaunchAtLogin", code: Int(exitCode), userInfo: [NSLocalizedDescriptionKey: msg.isEmpty ? "launchctl failed (\(exitCode))." : msg])
        }
        
        return exitCode
    }
}

