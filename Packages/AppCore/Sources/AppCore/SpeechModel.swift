import Foundation

public struct SpeechModel: Equatable, Sendable {
    public enum Level: Int, Sendable {
        case low = 2
        case medium = 3
        case high = 4
        case highest = 5
    }

    private static let repository = "https://huggingface.co/ggerganov/whisper.cpp/resolve/"
    private static let revision = "5359861c739e955e79d9a303bcbc70fb988958b1"
    private static let whisperLanguages = 99
    private static let largeV3Languages = 100
    private static let smallSize: Int64 = 487_601_967
    private static let baseSize: Int64 = 147_951_465
    private static let turboSize: Int64 = 1_624_555_275

    public static let all = [
        Self(
            id: "small", name: "Whisper Small", file: "ggml-small.bin", size: smallSize,
            sha256: "1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b",
            speed: .high, accuracy: .medium, languages: whisperLanguages, note: nil),
        Self(
            id: "base", name: "Whisper Base", file: "ggml-base.bin", size: baseSize,
            sha256: "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe",
            speed: .highest, accuracy: .low, languages: whisperLanguages, note: nil),
        Self(
            id: "large-v3-turbo", name: "Whisper Large v3 Turbo",
            file: "ggml-large-v3-turbo.bin", size: turboSize,
            sha256: "1fc70f774d38eb169993ac391eea357ef47c88757ef72ee5943879b7e8e2bc69",
            speed: .low, accuracy: .highest, languages: largeV3Languages,
            note: "recommended, best for Japanese"),
    ]

    public let id: String
    public let name: String
    let file: String
    public let size: Int64
    let sha256: String
    public let speed: Level
    public let accuracy: Level
    public let languages: Int
    public let note: String?

    var url: URL? {
        URL(string: "\(Self.repository)\(Self.revision)/\(file)")
    }
}
