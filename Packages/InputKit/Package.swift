// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "InputKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "InputKit", targets: ["InputKit"])
    ],
    dependencies: [
        .package(path: "../AppCore"),
    ],
    targets: [
        .target(name: "InputKit", dependencies: [.product(name: "AppCore", package: "AppCore")]),
        .testTarget(name: "InputKitTests", dependencies: ["InputKit"]),
    ]
)
