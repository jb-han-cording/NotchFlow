// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "NotchFlow", platforms: [.macOS(.v14)], products: [
    .executable(name: "NotchFlow", targets: ["NotchFlow"]),
    .library(name: "NotchFlowCore", targets: ["NotchFlowCore"])
], dependencies: [
    .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.10.0")
], targets: [
    .target(name: "NotchFlowCore"),
    .executableTarget(name: "NotchFlow", dependencies: ["NotchFlowCore", .product(name: "Sparkle", package: "Sparkle")])
])
