// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "InputKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "InputKit", targets: ["InputKit"])
    ],
    dependencies: [
        .package(path: "../AppCore")
    ],
    targets: [
        .target(
            name: "InputKit",
            dependencies: ["TouchPosition", .product(name: "AppCore", package: "AppCore")]),
        .target(name: "TouchPosition"),
        .testTarget(name: "InputKitTests", dependencies: ["InputKit"]),
    ]
)

for target in package.targets where target.name != "TouchPosition" {
    target.swiftSettings = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("ImmutableWeakCaptures"),
        .unsafeFlags(["-strict-memory-safety", "-warnings-as-errors"]),
    ]
}
