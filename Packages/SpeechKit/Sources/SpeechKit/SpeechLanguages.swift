import Foundation
import whisper

public struct SpeechLanguages: Codable, Equatable, Sendable {
    public static let supported: [String] = (0...Int(whisper_lang_max_id())).map { id in
        unsafe String(cString: whisper_lang_str(Int32(id)))
    }

    private static let standard = ["en", "ja"]

    public private(set) var codes: [String]

    public init() {
        codes = Self.standard
    }

    public init(from decoder: any Decoder) throws {
        let saved = try decoder.singleValueContainer().decode([String].self)
        var seen = Set<String>()
        let valid = saved.filter { Self.supported.contains($0) && seen.insert($0).inserted }
        codes = valid.isEmpty ? Self.standard : valid
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(codes)
    }

    public mutating func add(_ code: String) {
        guard Self.supported.contains(code), !codes.contains(code) else { return }
        codes.append(code)
    }

    public mutating func remove(_ code: String) {
        guard codes.count > 1 else { return }
        codes.removeAll { $0 == code }
    }
}
