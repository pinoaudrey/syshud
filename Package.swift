// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SysHUD",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "SysHUDCore"),
        .executableTarget(name: "SysHUD", dependencies: ["SysHUDCore"]),
        .testTarget(name: "SysHUDCoreTests", dependencies: ["SysHUDCore"]),
    ]
)
