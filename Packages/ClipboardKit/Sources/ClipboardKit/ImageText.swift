import CoreGraphics
import Dispatch
import Foundation
import ImageIO
import Vision

enum ImageText {
    struct Unreadable: Error {}

    static let longestSide = 4_096
    private static let languages = ["ja-JP", "en-US"]

    static func recognize(at file: URL) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(with: Result { try text(in: file) })
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
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
    }
}
