import Foundation

struct Units {
    static func bytes(_ bytes: UInt64) -> String {
        if bytes == 0 { return "0 B/s" }
        let units = ["B/s", "KB/s", "MB/s", "GB/s", "TB/s"]
        let i = Int(floor(log2(Double(bytes)) / log2(1024)))
        let count = Double(bytes) / pow(1024, Double(i))
        return String(format: "%.1f %@", count, units[i])
    }
}
