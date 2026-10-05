import FluidAudio
public import Foundation

public enum Parakeet {
    private static let versions: [AsrModelVersion] = [.v3, .tdtJa]

    static func version(folder: String) -> AsrModelVersion? {
        versions.first { AsrModels.defaultCacheDirectory(for: $0).lastPathComponent == folder }
    }

    public static func download(
        _ folder: String, into root: URL, progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        guard let version = version(folder: folder) else { throw CocoaError(.fileNoSuchFile) }
        let target = root.appending(path: folder)
        _ = try await AsrModels.download(to: target, version: version) { step in
            progress(step.fractionCompleted)
        }
    }
}
