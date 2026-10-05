import Foundation
import os

public struct SpeechModel: Equatable, Sendable {
    public enum Engine: Sendable {
        case whisper
        case parakeet
    }

    public enum Level: Int, Sendable {
        case lowest = 1
        case low = 2
        case medium = 3
        case high = 4
        case highest = 5
    }

    private enum Family: String {
        case tiny = "tiny"
        case base = "base"
        case small = "small"
        case medium = "medium"
        case largeV1 = "large-v1"
        case largeV2 = "large-v2"
        case largeV3 = "large-v3"
        case turbo = "large-v3-turbo"

        var name: String {
            switch self {
            case .tiny: "Tiny"
            case .base: "Base"
            case .small: "Small"
            case .medium: "Medium"
            case .largeV1: "Large v1"
            case .largeV2: "Large v2"
            case .largeV3: "Large v3"
            case .turbo: "Large v3 Turbo"
            }
        }

        var speed: Level {
            switch self {
            case .tiny, .base: .highest
            case .small: .high
            case .turbo: .medium
            case .medium: .low
            case .largeV1, .largeV2, .largeV3: .lowest
            }
        }

        var summary: String {
            switch self {
            case .tiny: "Smallest and fastest, with the most mistakes."
            case .base: "Very fast and light, with fair accuracy."
            case .small: "Fast. Good for English, weaker in Japanese."
            case .medium: "More accurate than Small, but slower."
            case .largeV1: "The first large model. Large v3 replaces it."
            case .largeV2: "An older large model. Large v3 is more accurate."
            case .largeV3: "The most accurate, and the slowest. Turbo comes close."
            case .turbo: "Best for Japanese and English. Close to Large v3, much faster."
            }
        }

        var memory: Int64 {
            switch self {
            case .tiny: tinyMemory
            case .base: baseMemory
            case .small: smallMemory
            case .medium: mediumMemory
            case .largeV1, .largeV2, .largeV3: largeMemory
            case .turbo: turboMemory
            }
        }

        var accuracy: Level {
            switch self {
            case .tiny: .lowest
            case .base: .low
            case .small, .largeV1: .medium
            case .medium, .largeV2: .high
            case .largeV3, .turbo: .highest
            }
        }

        var languages: Int {
            switch self {
            case .largeV3, .turbo: largeV3Languages
            default: whisperLanguages
            }
        }
    }

    private struct Entry: Decodable {
        let file: String
        let size: Int64
        let sha256: String
    }

    private static let repository = "https://huggingface.co/ggerganov/whisper.cpp/resolve/"
    private static let revision = "5359861c739e955e79d9a303bcbc70fb988958b1"
    private static let whisperLanguages = 99
    private static let largeV3Languages = 100
    private static let tinyMemory: Int64 = 273_000_000
    private static let baseMemory: Int64 = 388_000_000
    private static let smallMemory: Int64 = 852_000_000
    private static let mediumMemory: Int64 = 2_100_000_000
    private static let largeMemory: Int64 = 3_900_000_000
    private static let turboMemory: Int64 = 1_900_000_000
    private static let prefix = "ggml-"
    private static let suffix = ".bin"
    private static let english = ".en"
    private static let quantized = "-q"

    public static let all = catalog() + parakeet

    public let id: String
    public let name: String
    let file: String
    public let size: Int64
    let sha256: String?
    public let engine: Engine
    public let isEnglishOnly: Bool
    public let isJapaneseOnly: Bool
    public let isCompressed: Bool
    let isFiveBit: Bool
    public let isMeasured: Bool
    public let isRecommended: Bool
    public let speed: Level
    public let accuracy: Level
    public let languages: Int
    public let summary: String
    public let memory: Int64?

    var url: URL? {
        guard engine == .whisper else { return nil }
        return URL(string: "\(Self.repository)\(Self.revision)/\(file)")
    }

    init(file: String, size: Int64, sha256: String) throws {
        guard file.hasPrefix(Self.prefix), file.hasSuffix(Self.suffix) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let key = String(file.dropFirst(Self.prefix.count).dropLast(Self.suffix.count))
        let parts = key.components(separatedBy: Self.quantized)
        let stem = parts[0]
        let englishOnly = stem.hasSuffix(Self.english)
        guard
            let family = Family(
                rawValue: englishOnly ? String(stem.dropLast(Self.english.count)) : stem)
        else { throw CocoaError(.fileReadCorruptFile) }
        let quantization = parts.dropFirst().first
        id = key
        self.file = file
        self.size = size
        self.sha256 = sha256
        engine = .whisper
        isEnglishOnly = englishOnly
        isJapaneseOnly = false
        isCompressed = quantization != nil
        let fullSize = !englishOnly && !isCompressed
        isMeasured = fullSize && (family == .small || family == .turbo)
        isRecommended = fullSize && family == .turbo
        speed = family.speed
        let fiveBit = quantization?.hasPrefix("5") == true
        isFiveBit = fiveBit
        accuracy =
            fiveBit ? Level(rawValue: family.accuracy.rawValue - 1) ?? .lowest : family.accuracy
        languages = englishOnly ? 1 : family.languages
        summary = Self.summary(
            of: family, englishOnly: englishOnly, compressed: isCompressed, fiveBit: fiveBit)
        memory = isCompressed ? nil : family.memory
        name = [
            "Whisper", family.name, englishOnly ? "English" : nil,
            quantization.map { "Q\($0.prefix(1))" },
        ]
        .compactMap(\.self).joined(separator: " ")
    }

    private static func summary(
        of family: Family, englishOnly: Bool, compressed: Bool, fiveBit: Bool
    ) -> String {
        let label = englishOnly ? "\(family.name) for English only" : family.name
        if fiveBit {
            return "\(label), compressed to a third of the size and slightly less accurate."
        }
        if compressed {
            return "\(label), compressed to half the size."
        }
        return englishOnly ? "\(label). It can’t transcribe Japanese." : family.summary
    }

    private static func catalog() -> [Self] {
        do {
            guard
                let resource = Bundle.module.url(forResource: "SpeechModels", withExtension: "json")
            else { throw CocoaError(.fileNoSuchFile) }
            let entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: resource))
            return try entries.map { entry in
                try Self(file: entry.file, size: entry.size, sha256: entry.sha256)
            }
        } catch {
            Log.logger("SpeechModel").error(
                "The speech model catalog failed to load: \(error, privacy: .public)")
            return []
        }
    }

    public func advantage(over other: Self) -> String? {
        let moreAccurate = accuracy.rawValue > other.accuracy.rawValue
        let faster = speed.rawValue > other.speed.rawValue
        if moreAccurate {
            return faster ? "more accurate and faster" : "more accurate"
        }
        return faster && accuracy == other.accuracy ? "as accurate and faster" : nil
    }
}
