// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SearchKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SearchKit", targets: ["SearchKit"])
    ],
    dependencies: [
        .package(path: "../AppCore")
    ],
    targets: [
        .target(name: "SearchKit", dependencies: [.product(name: "AppCore", package: "AppCore")]),
        .testTarget(name: "SearchKitTests", dependencies: ["SearchKit"]),
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
