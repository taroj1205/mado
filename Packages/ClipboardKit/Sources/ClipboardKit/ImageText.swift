public import CoreGraphics
import Dispatch
import Foundation
import ImageIO
import NaturalLanguage
import Vision

public enum ImageText {
    public struct Recognition: Sendable {
        public let text: String
        public let language: String?
    }

    struct Piece {
        private static let half: CGFloat = 0.5

        let box: CGRect
        let text: String

        func sharesRow(with other: Self) -> Bool {
            abs(box.midY - other.box.midY) < min(box.height, other.box.height) * Self.half
        }
    }

    struct Unreadable: Error {}

    static let longestSide = 4_096
    private static let languages = ["ja-JP", "en-US"]

    static func recognize(at file: URL) async throws -> String {
        try await run { try text(in: file) }
    }

    public static func recognize(_ image: CGImage) async throws -> Recognition {
        let text = try await run { try text(in: image) }
        return Recognition(text: text, language: language(of: text))
    }

    private static func language(of text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = languages.compactMap { identifier in
            Locale.Language(identifier: identifier).languageCode.map { NLLanguage($0.identifier) }
        }
        recognizer.processString(text)
        return recognizer.dominantLanguage?.rawValue
    }

    private static func run<Value: Sendable>(
        _ work: @escaping @Sendable () throws -> Value
    ) async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(with: Result(catching: work))
            }
        }
    }

    static func image(at file: URL) -> CGImage? {
        let options =
            [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: longestSide,
            ] as CFDictionary
        return CGImageSourceCreateWithURL(file as CFURL, nil).flatMap { source in
            CGImageSourceCreateThumbnailAtIndex(source, 0, options)
        }
    }

    private static func text(in file: URL) throws -> String {
        guard let image = image(at: file) else { throw Unreadable() }
        return try text(in: image)
    }

    private static func text(in image: CGImage) throws -> String {
        do {
            return try text(in: image, level: .accurate)
        } catch {
            return try text(in: image, level: .fast)
        }
    }

    private static func text(
        in image: CGImage, level: VNRequestTextRecognitionLevel
    ) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = level
        let supported = try request.supportedRecognitionLanguages()
        request.recognitionLanguages = languages.filter(supported.contains)
        request.preferBackgroundProcessing = true
        try VNImageRequestHandler(cgImage: image).perform([request])
        let pieces = (request.results ?? []).compactMap { observation in
            observation.topCandidates(1).first.map { candidate in
                Piece(box: observation.boundingBox, text: candidate.string)
            }
        }
        return lines(of: pieces)
    }

    static func lines(of pieces: [Piece]) -> String {
        var rows: [[Piece]] = []
        for piece in pieces.sorted(by: { $0.box.midY > $1.box.midY }) {
            if let anchor = rows.last?.first, anchor.sharesRow(with: piece) {
                rows[rows.count - 1].append(piece)
            } else {
                rows.append([piece])
            }
        }
        let lines = rows.map { row in
            row.sorted { left, right in left.box.minX < right.box.minX }.map(\.text)
        }
        return lines.map { $0.joined(separator: " ") }.joined(separator: "\n")
    }
}
