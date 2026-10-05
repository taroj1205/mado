import CryptoKit
public import Foundation

public struct SpeechModelStore: Sendable {
    public enum Failure: LocalizedError {
        case badResponse
        case corrupt

        public var errorDescription: String? {
            switch self {
            case .badResponse: "The server didn’t send the model."
            case .corrupt: "The downloaded model didn’t match its checksum, so it wasn’t kept."
            }
        }
    }

    private static let chunk = 4 << 20
    private static let hexRadix = 16

    public static let standard = Self(
        directory: .applicationSupportDirectory.appending(path: "Mado/Models"))

    let directory: URL

    @concurrent
    static func sha256(of file: URL) async throws -> String {
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hash = SHA256()
        while let data = try handle.read(upToCount: chunk), !data.isEmpty {
            try Task.checkCancellation()
            hash.update(data: data)
        }
        let bytes = hash.finalize().map { ($0 < hexRadix ? "0" : "") + String($0, radix: hexRadix) }
        return bytes.joined()
    }

    func location(of model: SpeechModel) -> URL {
        directory.appending(path: model.file)
    }

    public func isInstalled(_ model: SpeechModel) -> Bool {
        FileManager.default.fileExists(atPath: location(of: model).path(percentEncoded: false))
    }

    public func model(preferring id: String?) -> SpeechModel? {
        let installed = SpeechModel.all.filter(isInstalled)
        return installed.first { $0.id == id } ?? installed.first
    }

    public func delete(_ model: SpeechModel) throws {
        try FileManager.default.removeItem(at: location(of: model))
    }

    public func download(
        _ model: SpeechModel, progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        guard let url = model.url else { throw URLError(.badURL) }
        try await download(model, from: url, progress: progress)
    }

    func download(
        _ model: SpeechModel, from url: URL, progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let transfer = SpeechModelTransfer(size: model.size, progress: progress)
        let session = URLSession(
            configuration: .ephemeral, delegate: transfer, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        let file = try await transfer.start(session.downloadTask(with: url))
        defer { try? FileManager.default.removeItem(at: file) }
        guard try await Self.sha256(of: file) == model.sha256 else { throw Failure.corrupt }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: file, to: location(of: model))
    }
}
