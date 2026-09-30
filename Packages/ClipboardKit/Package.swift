// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClipboardKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ClipboardKit", targets: ["ClipboardKit"])
    ],
    dependencies: [
        .package(path: "../AppCore"),
        .package(path: "../InputKit"),
    ],
    targets: [
        .target(name: "ClipboardKit", dependencies: [.product(name: "AppCore", package: "AppCore"), .product(name: "InputKit", package: "InputKit")]),
        .testTarget(name: "ClipboardKitTests", dependencies: ["ClipboardKit"]),
    ]
)
