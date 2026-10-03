import AppCore
import Foundation
import os

extension ClipboardStore {
    private static let logger = Log.logger("ClipboardStore")

    public func recognizeImages() async throws {
        try await recognizeImages(using: ImageText.recognize)
    }

    func recognizeImages(
        using recognize: @escaping @Sendable (URL) async throws -> String
    ) async throws {
        let previous = recognition
        let task = Task {
            _ = await previous?.result
            try await recognizePending(using: recognize)
        }
        recognition = task
        try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func recognizePending(
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
