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
        .target(
            name: "ClipboardKit",
            dependencies: [
                .product(name: "AppCore", package: "AppCore"),
                .product(name: "InputKit", package: "InputKit"),
            ],
            resources: [.copy("Resources/emoji.tsv")]),
        .testTarget(name: "ClipboardKitTests", dependencies: ["ClipboardKit"]),
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
