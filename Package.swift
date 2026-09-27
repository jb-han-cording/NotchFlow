// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "NotchFlow", platforms: [.macOS(.v14)], products: [
    .executable(name: "NotchFlow", targets: ["NotchFlow"]),
    .library(name: "NotchFlowCore", targets: ["NotchFlowCore"])
], targets: [
    .target(name: "NotchFlowCore"),
    .executableTarget(name: "NotchFlow", dependencies: ["NotchFlowCore"]),
    .testTarget(name: "NotchFlowCoreTests", dependencies: ["NotchFlowCore"]),
    .testTarget(name: "NotchFlowTests", dependencies: ["NotchFlow", "NotchFlowCore"])
])
