// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WindowKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "WindowKit", targets: ["WindowKit"])
    ],
    dependencies: [
        .package(path: "../AppCore")
    ],
    targets: [
        .target(name: "WindowKit", dependencies: [.product(name: "AppCore", package: "AppCore")]),
        .testTarget(name: "WindowKitTests", dependencies: ["WindowKit"]),
    ]
)

for target in package.targets {
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
