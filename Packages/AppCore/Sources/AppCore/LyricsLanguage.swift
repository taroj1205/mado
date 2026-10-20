enum LyricsLanguage: CaseIterable {
    case japanese
    case korean

    private static let kana: [ClosedRange<Unicode.Scalar>] = [
        "\u{3040}"..."\u{30FF}", "\u{31F0}"..."\u{31FF}",
    ]
    private static let hangul: [ClosedRange<Unicode.Scalar>] = [
        "\u{1100}"..."\u{11FF}", "\u{3130}"..."\u{318F}", "\u{AC00}"..."\u{D7AF}",
    ]
    private static let enoughShare = 0.1

    private var script: [ClosedRange<Unicode.Scalar>] {
        switch self {
        case .japanese: Self.kana
        case .korean: Self.hangul
        }
    }

    init?(detecting lyrics: Lyrics) {
        let letters = lyrics.lines.lazy.flatMap(\.text.unicodeScalars)
            .filter(\.properties.isAlphabetic)
        let total = Double(letters.count)
        let found = Self.allCases.first { language in
            let written = letters.filter { letter in
                language.script.contains { $0.contains(letter) }
            }
            return !written.isEmpty && Double(written.count) >= total * Self.enoughShare
        }
        guard let found else { return nil }
        self = found
    }

    static func prevailing(in languages: [Self]) -> Self? {
        let counts = Dictionary(grouping: languages, by: \.self).mapValues(\.count)
        return allCases.filter { counts[$0] != nil }
            .max { counts[$0, default: 0] < counts[$1, default: 0] }
    }
}
