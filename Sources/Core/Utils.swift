import Foundation

struct Units {
    static func bytes(_ bytes: UInt64) -> String {
        if bytes == 0 { return "0 B/s" }
        let units = ["B/s", "KB/s", "MB/s", "GB/s", "TB/s"]
        let i = Int(floor(log2(Double(bytes)) / log2(1024)))
        let count = Double(bytes) / pow(1024, Double(i))
        return String(format: "%.1f %@", count, units[i])
    }
    
    static func bytesTotal(_ bytes: UInt64) -> String {
        if bytes == 0 { return "0 B" }
        let units = ["B", "KB", "MB", "GB", "TB"]
        let i = min(Int(floor(log2(Double(bytes)) / log2(1024))), units.count - 1)
        let count = Double(bytes) / pow(1024, Double(i))
        return String(format: "%.1f %@", count, units[i])
    }

    static func statusRate(_ bytes: UInt64) -> String {
        let units = ["KB/s", "MB/s", "GB/s", "TB/s"]
        let magnitude = bytes == 0 ? 1 : Int(floor(log2(Double(bytes)) / log2(1024)))
        let unitIndex = max(0, min(magnitude - 1, units.count - 1))
        let value = Double(bytes) / pow(1024, Double(unitIndex + 1))
        let number = value < 10 ? String(format: "%.1f", value) : String(format: "%.0f", value)
        return number + " " + units[unitIndex]
    }
}
