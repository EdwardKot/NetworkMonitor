import Foundation

struct NetworkStats {
    let upload: UInt64
    let download: UInt64
}

class NetworkReader {
    private var lastStats: [String: (ibytes: UInt64, obytes: UInt64)] = [:]
    
    func read() -> NetworkStats {
        let currentStats = getInterfaceStats()
        var totalUpload: UInt64 = 0
        var totalDownload: UInt64 = 0
        
        for (name, stats) in currentStats {
            if let last = lastStats[name] {
                // Handle overflow (though unlikely for 64-bit in short intervals)
                if stats.ibytes >= last.ibytes {
                    totalDownload += stats.ibytes - last.ibytes
                }
                if stats.obytes >= last.obytes {
                    totalUpload += stats.obytes - last.obytes
                }
            }
        }
        
        lastStats = currentStats
        return NetworkStats(upload: totalUpload, download: totalDownload)
    }
    
    private func getInterfaceStats() -> [String: (ibytes: UInt64, obytes: UInt64)] {
        var stats: [String: (ibytes: UInt64, obytes: UInt64)] = [:]
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return [:] }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while ptr != nil {
            let interface = ptr!.pointee
            let name = String(cString: interface.ifa_name)
            
            // Skip Loopback
            if (interface.ifa_flags & UInt32(IFF_LOOPBACK)) == 0 {
                let addr = interface.ifa_addr.pointee
                if addr.sa_family == UInt8(AF_LINK) {
                    let data = interface.ifa_data.assumingMemoryBound(to: if_data.self)
                    stats[name] = (ibytes: UInt64(data.pointee.ifi_ibytes), obytes: UInt64(data.pointee.ifi_obytes))
                }
            }
            ptr = interface.ifa_next
        }
        return stats
    }
}
