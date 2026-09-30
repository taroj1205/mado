// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SearchKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SearchKit", targets: ["SearchKit"])
    ],
    dependencies: [
        .package(path: "../AppCore"),
    ],
    targets: [
        .target(name: "SearchKit", dependencies: [.product(name: "AppCore", package: "AppCore")]),
        .testTarget(name: "SearchKitTests", dependencies: ["SearchKit"]),
    ]
)
