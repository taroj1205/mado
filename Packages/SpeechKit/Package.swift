// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SpeechKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "SpeechKit", targets: ["SpeechKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.17.5")
    ],
    targets: [
        .binaryTarget(
            name: "whisper",
            url: "https://github.com/ggml-org/whisper.cpp/releases/download/b5130/"
                + "whisper-b5130-xcframework.zip",
            checksum: "033a43b0174e8cf9b366f72e4a428cdcf126f93ad1c87d3fa119a96bed6f231a"),
        .target(
            name: "SpeechKit",
            dependencies: ["whisper", .product(name: "FluidAudio", package: "FluidAudio")]),
        .testTarget(name: "SpeechKitTests", dependencies: ["SpeechKit"]),
    ]
)

for target in package.targets where target.type != .binary {
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
