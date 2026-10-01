import Foundation

public enum Fuzzy {
    private typealias Letter = (character: Character, wordStart: Bool)

    private static let nameStartBonus = 8
    static let wordStartBonus = 8
    private static let consecutiveBonus = 4

    public static func rank<Item>(
        _ items: [Item], by query: String, bonus: (Item) -> Int = { _ in 0 },
        keys: (Item) -> [String]
    ) -> [Item] {
        let needle = fold(query.trimmingCharacters(in: .whitespacesAndNewlines)).map(\.character)
        let scored = items.enumerated().compactMap { offset, item in
            let best =
                needle.isEmpty ? 0 : keys(item).compactMap { score(needle, in: fold($0)) }.max()
            return best.map { (item: item, score: $0 + bonus(item), offset: offset) }
        }
        return scored.sorted { ($1.score, $0.offset) < ($0.score, $1.offset) }.map(\.item)
    }

    private static func score(_ needle: [Character], in text: [Letter]) -> Int? {
        var row = [Int?](repeating: nil, count: text.count)
        for (step, wanted) in needle.enumerated() {
            var next = [Int?](repeating: nil, count: text.count)
            var gap: Int? = step == 0 ? 0 : nil
            var previous: Int?
            for index in text.indices {
                if text[index].character == wanted {
                    let gain =
                        1 + (text[index].wordStart ? wordStartBonus : 0)
                        + (index == 0 ? nameStartBonus : 0)
                    let joined = previous.map { $0 + gain + consecutiveBonus }
                    next[index] = [joined, gap.map { $0 + gain }].compactMap(\.self).max()
                }
                gap = [gap, previous].compactMap(\.self).max()
                previous = row[index]
            }
            row = next
        }
        return row.compactMap(\.self).max()
    }

    private static func fold(_ text: String) -> [Letter] {
        let latin = text.allSatisfy(\.isASCII) ? text : romanized(text)
        var folded: [Letter] = []
        var before: Character?
        for character in latin {
            let wordStart =
                before.map { previous in
                    !(previous.isLetter || previous.isNumber)
                        || (previous.isLowercase && character.isUppercase)
                } ?? true
            let plain =
                character.isASCII
                ? character.lowercased()
                : String(character).folding(
                    options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                    locale: nil)
            for (offset, piece) in plain.enumerated() {
                folded.append((piece, wordStart && offset == 0))
            }
            before = character
        }
        return folded
    }

    private static func romanized(_ text: String) -> String {
        text.replacing(/[\p{Script=Hiragana}\p{Script=Katakana}ー]+/) { match in
            let kana = String(match.output)
            let katakana = kana.applyingTransform(.hiraganaToKatakana, reverse: false) ?? kana
            let latin = katakana.applyingTransform(.latinToKatakana, reverse: true) ?? katakana
            return latin.filter(\.isLetter)
        }
    }
}
