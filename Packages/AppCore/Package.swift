// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AppCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AppCore", targets: ["AppCore"])
    ],
    dependencies: [],
    targets: [
        .target(name: "AppCore", dependencies: [], resources: [.process("SpeechModels.json")]),
        .testTarget(name: "AppCoreTests", dependencies: ["AppCore"]),
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
