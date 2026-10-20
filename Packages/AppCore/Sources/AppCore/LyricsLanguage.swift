public enum LyricsLanguage: String, CaseIterable, Sendable {
    case any = "automatic"
    case japanese = "japanese"
    case korean = "korean"

    private static let kana: [ClosedRange<Unicode.Scalar>] = [
        "\u{3040}"..."\u{30FF}", "\u{31F0}"..."\u{31FF}",
    ]
    private static let hangul: [ClosedRange<Unicode.Scalar>] = [
        "\u{1100}"..."\u{11FF}", "\u{3130}"..."\u{318F}", "\u{AC00}"..."\u{D7AF}",
    ]
    private static let enoughShare = 0.1

    public var title: String {
        switch self {
        case .any: "Automatic"
        case .japanese: "Japanese"
        case .korean: "Korean"
        }
    }

    private var script: [ClosedRange<Unicode.Scalar>] {
        switch self {
        case .any: []
        case .japanese: Self.kana
        case .korean: Self.hangul
        }
    }

    public func accepts(_ lyrics: Lyrics) -> Bool {
        if script.isEmpty { return true }
        let letters = lyrics.lines.lazy.flatMap(\.text.unicodeScalars)
            .filter(\.properties.isAlphabetic)
        let written = letters.filter { letter in script.contains { $0.contains(letter) } }
        return !written.isEmpty && Double(written.count) >= Double(letters.count) * Self.enoughShare
    }
}
