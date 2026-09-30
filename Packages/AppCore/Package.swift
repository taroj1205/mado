// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AppCore", targets: ["AppCore"])
    ],
    dependencies: [
    ],
    targets: [
        .target(name: "AppCore", dependencies: []),
        .testTarget(name: "AppCoreTests", dependencies: ["AppCore"]),
    ]
)
