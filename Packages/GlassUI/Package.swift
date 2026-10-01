// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GlassUI",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "GlassUI", targets: ["GlassUI"])
    ],
    dependencies: [
        .package(path: "../AppCore")
    ],
    targets: [
        .target(name: "GlassUI", dependencies: [.product(name: "AppCore", package: "AppCore")]),
        .testTarget(name: "GlassUITests", dependencies: ["GlassUI"]),
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
