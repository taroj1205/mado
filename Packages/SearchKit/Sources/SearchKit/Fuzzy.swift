import Foundation

public enum Fuzzy {
    public struct Key: Sendable, Equatable {
        let letters: [Letter]

        public init(_ text: String) {
            letters = Fuzzy.fold(text)
        }
    }

    struct Letter: Sendable, Equatable {
        let character: Character
        let wordStart: Bool
    }

    private static let nameStartBonus = 8
    static let wordStartBonus = 8
    private static let consecutiveBonus = 4

    public static func rank<Item>(
        _ items: [Item], by query: String, bonus: (Item) -> Int = { _ in 0 },
        keys: (Item) -> [String]
    ) -> [Item] {
        rank(items, by: query, bonus: bonus) { keys($0).map(Key.init) }
    }

    public static func rank<Item>(
        _ items: [Item], by query: String, bonus: (Item) -> Int = { _ in 0 },
        keys: (Item) -> [Key]
    ) -> [Item] {
        let needle = Key(query.trimmingCharacters(in: .whitespacesAndNewlines)).letters
            .map(\.character)
        var scored: [(score: Int, offset: Int)] = []
        for (offset, item) in items.enumerated() {
            let best =
                needle.isEmpty ? 0 : keys(item).compactMap { score(needle, in: $0.letters) }.max()
            if let best {
                scored.append((best + bonus(item), offset))
            }
        }
        scored.sort { ($1.score, $0.offset) < ($0.score, $1.offset) }
        return scored.map { items[$0.offset] }
    }

    private static func score(_ needle: [Character], in text: [Letter]) -> Int? {
        var matched = 0
        for letter in text where matched < needle.count && letter.character == needle[matched] {
            matched += 1
        }
        guard matched == needle.count else { return nil }
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
                    next[index] = larger(joined, gap.map { $0 + gain })
                }
                gap = larger(gap, previous)
                previous = row[index]
            }
            row = next
        }
        return row.compactMap(\.self).max()
    }

    private static func larger(_ first: Int?, _ second: Int?) -> Int? {
        guard let first, let second else { return first ?? second }
        return max(first, second)
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
                folded.append(Letter(character: piece, wordStart: wordStart && offset == 0))
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
