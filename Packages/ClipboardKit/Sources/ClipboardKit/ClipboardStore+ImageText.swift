import AppCore
import Foundation
import os

extension ClipboardStore {
    private static let logger = Log.logger("ClipboardStore")

    public func recognizeImages(onEach saved: (@Sendable () async -> Void)? = nil) async throws {
        try await recognizeImages(onEach: saved, using: ImageText.recognize)
    }

    func recognizeImages(
        onEach saved: (@Sendable () async -> Void)?,
        using recognize: @escaping @Sendable (URL) async throws -> String
    ) async throws {
        let previous = recognition
        let task = Task {
            _ = await previous?.result
            try await recognizePending(onEach: saved, using: recognize)
        }
        recognition = task
        try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func recognizePending(
        onEach saved: (@Sendable () async -> Void)?,
        using recognize: @Sendable (URL) async throws -> String
    ) async throws {
        while !Task.isCancelled, let image = try unrecognizedImage() {
            let text: String
            do {
                text = try await recognize(images.appending(path: image.file))
            } catch {
                Self.logger.error(
                    "Recognising text in an image failed: \(error, privacy: .public)")
                text = ""
            }
            try database.run(
                "UPDATE clips SET text = ?, recognized = 1 WHERE id = ? AND image = ?",
                [.text(text), .integer(Int(image.id)), .text(image.file)])
            await saved?()
        }
    }

    private func unrecognizedImage() throws -> (id: Int64, file: String)? {
        try database.rows(
            "SELECT id, image FROM clips WHERE recognized = 0 AND image IS NOT NULL"
                + " ORDER BY date DESC, id DESC LIMIT 1",
            []
        ) { row in row.string(1).map { (id: row.integer(0), file: $0) } }
        .first
    }
}
