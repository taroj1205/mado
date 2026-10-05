import Foundation

public enum Fuzzy {
    public struct Key: Sendable, Equatable {
        let letters: [Letter]

        public init(_ text: String) {
            letters = Fuzzy.fold(text)
        }
    }

    public struct Match: Sendable, Equatable {
        public let score: Int
        public let offsets: [Int]
    }

    private struct Cell {
        let score: Int
        let from: Int?
    }

    struct Letter: Sendable, Equatable {
        let character: Character
        let wordStart: Bool
        let offset: Int
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

    public static func match(_ query: String, in text: String) -> Match? {
        let needle = Key(query.trimmingCharacters(in: .whitespacesAndNewlines)).letters
            .map(\.character)
        let letters = fold(text)
        guard !needle.isEmpty, let best = align(needle, in: letters) else { return nil }
        let shifted = !text.allSatisfy(\.isASCII) && romanized(text) != text
        let offsets = shifted ? [] : Set(best.path.map { letters[$0].offset }).sorted()
        return Match(score: best.score, offsets: offsets)
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
                    let gain = gain(at: index, in: text)
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

    private static func align(
        _ needle: [Character], in text: [Letter]
    ) -> (score: Int, path: [Int])? {
        var rows: [[Cell?]] = []
        for (step, wanted) in needle.enumerated() {
            rows.append(advance(rows.last ?? [], to: wanted, first: step == 0, in: text))
        }
        guard let last = rows.last,
            let end = last.indices.max(by: { last[$0]?.score ?? .min < last[$1]?.score ?? .min }),
            let cell = last[end]
        else { return nil }
        var path = [end]
        for row in rows.dropFirst().reversed() {
            guard let index = path.last, let from = row[index]?.from else { return nil }
            path.append(from)
        }
        return (cell.score, path.reversed())
    }

    private static func advance(
        _ row: [Cell?], to wanted: Character, first: Bool, in text: [Letter]
    ) -> [Cell?] {
        var next = [Cell?](repeating: nil, count: text.count)
        var gap: Cell? = first ? Cell(score: 0, from: nil) : nil
        var previous: Cell?
        for index in text.indices {
            if text[index].character == wanted {
                let gain = gain(at: index, in: text)
                let joined = previous.map { cell in
                    Cell(score: cell.score + gain + consecutiveBonus, from: index - 1)
                }
                let skipped = gap.map { Cell(score: $0.score + gain, from: $0.from) }
                if let joined, joined.score >= skipped?.score ?? .min {
                    next[index] = joined
                } else {
                    next[index] = skipped
                }
            }
            if let previous, previous.score > gap?.score ?? .min {
                gap = Cell(score: previous.score, from: index - 1)
            }
            previous = row.isEmpty ? nil : row[index]
        }
        return next
    }

    private static func gain(at index: Int, in text: [Letter]) -> Int {
        1 + (text[index].wordStart ? wordStartBonus : 0) + (index == 0 ? nameStartBonus : 0)
    }

    private static func larger(_ first: Int?, _ second: Int?) -> Int? {
        guard let first, let second else { return first ?? second }
        return max(first, second)
    }

    private static func fold(_ text: String) -> [Letter] {
        let latin = text.allSatisfy(\.isASCII) ? text : romanized(text)
        var folded: [Letter] = []
        var before: Character?
        for (index, character) in latin.enumerated() {
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
                folded.append(
                    Letter(character: piece, wordStart: wordStart && offset == 0, offset: index))
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
