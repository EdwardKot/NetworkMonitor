// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NetworkMonitor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "NetworkMonitor", targets: ["NetworkMonitor"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "NetworkMonitor",
            dependencies: [],
            path: "Sources"
        )
    ]
)
