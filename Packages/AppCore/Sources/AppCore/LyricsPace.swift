import Foundation

enum LyricsPace {
    struct Beat: Equatable {
        let width: Double
        let morae: Double
    }

    private static let wide = 1.0
    private static let narrow = 0.55
    private static let gap = 0.3
    private static let japaneseStart: Unicode.Scalar = "\u{3040}"
    private static let hiragana: ClosedRange<Unicode.Scalar> = "ぁ"..."ゖ"
    private static let katakana: ClosedRange<Unicode.Scalar> = "ァ"..."ヺ"
    private static let prolonged: Unicode.Scalar = "ー"
    private static let smallKana = Set("ぁぃぅぇぉゃゅょゎァィゥェォャュョヮ".unicodeScalars)
    private static let vowels = Set("aeiouyAEIOUY".unicodeScalars)
    private static let wideRanges: [ClosedRange<Unicode.Scalar>] = [
        "\u{1100}"..."\u{115F}", "\u{2E80}"..."\u{A4CF}", "\u{AC00}"..."\u{D7A3}",
        "\u{F900}"..."\u{FAFF}", "\u{FE30}"..."\u{FE6F}", "\u{FF00}"..."\u{FF60}",
        "\u{FFE0}"..."\u{FFE6}", "\u{1F000}"..."\u{1FAFF}",
    ]

    static func morae(in text: String) -> Int {
        Int(beats(of: text).reduce(0) { $0 + $1.morae }.rounded())
    }

    static func beats(of text: String) -> [Beat] {
        var result: [Beat] = []
        var cursor = text.startIndex
        for word in words(in: text) {
            result += text[cursor..<word.range.lowerBound].map { beat(width: $0, morae: 0) }
            result += beats(ofWord: text[word.range], reading: word.reading)
            cursor = word.range.upperBound
        }
        result += text[cursor...].map { beat(width: $0, morae: 0) }
        return result
    }

    private static func words(in text: String) -> [(range: Range<String.Index>, reading: String?)] {
        let length = text.utf16.count
        guard
            let tokenizer = CFStringTokenizerCreate(
                nil, text as CFString, CFRangeMake(0, length),
                kCFStringTokenizerUnitWord, Locale(identifier: "ja") as CFLocale)
        else { return [] }
        var found: [(range: Range<String.Index>, reading: String?)] = []
        while CFStringTokenizerAdvanceToNextToken(tokenizer).rawValue != 0 {
            let span = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            let start = String.Index(utf16Offset: span.location, in: text)
            let end = String.Index(utf16Offset: span.location + span.length, in: text)
            guard start >= (found.last?.range.upperBound ?? text.startIndex) else { continue }
            found.append((start..<end, reading(of: text[start..<end], from: tokenizer)))
        }
        return found
    }

    private static func reading(of word: Substring, from tokenizer: CFStringTokenizer) -> String? {
        guard word.unicodeScalars.contains(where: { $0 >= japaneseStart }),
            let latin = CFStringTokenizerCopyCurrentTokenAttribute(
                tokenizer, kCFStringTokenizerAttributeLatinTranscription) as? String
        else { return nil }
        return latin.applyingTransform(.latinToHiragana, reverse: false)
    }

    private static func beats(ofWord word: Substring, reading: String?) -> [Beat] {
        let letters = Array(word)
        guard let reading else {
            let each = Double(count(word)) / Double(max(letters.filter(isLetter).count, 1))
            return letters.map { beat(width: $0, morae: isLetter($0) ? each : 0) }
        }
        let own = letters.map { count(String($0)) }
        let others = letters.filter { !isKana($0) }.count
        let spare = max(Double(count(reading) - own.reduce(0, +)), Double(others))
        return zip(letters, own).map { letter, kana in
            beat(width: letter, morae: isKana(letter) ? Double(kana) : spare / Double(others))
        }
    }

    private static func beat(width letter: Character, morae: Double) -> Beat {
        Beat(width: width(of: letter), morae: morae)
    }

    private static func width(of letter: Character) -> Double {
        guard let scalar = letter.unicodeScalars.first else { return 0 }
        if letter.isWhitespace { return gap }
        return wideRanges.contains { $0.contains(scalar) } ? wide : narrow
    }

    private static func isKana(_ letter: Character) -> Bool {
        letter.unicodeScalars.allSatisfy { scalar in
            hiragana.contains(scalar) || katakana.contains(scalar) || scalar == prolonged
        }
    }

    private static func isLetter(_ letter: Character) -> Bool {
        letter.isLetter || letter.isNumber
    }

    private static func count(_ text: some StringProtocol) -> Int {
        var total = 0
        var inVowels = false
        for scalar in text.unicodeScalars {
            if hiragana.contains(scalar) || katakana.contains(scalar) || scalar == prolonged {
                if !smallKana.contains(scalar) { total += 1 }
                inVowels = false
            } else if vowels.contains(scalar) {
                if !inVowels { total += 1 }
                inVowels = true
            } else {
                inVowels = false
            }
        }
        return total
    }
}
