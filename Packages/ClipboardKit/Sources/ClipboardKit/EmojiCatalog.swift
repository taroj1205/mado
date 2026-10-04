import AppKit
import CoreText
import Foundation

public struct EmojiCatalog: Sendable {
    public struct Group: Equatable, Sendable {
        public let name: String
        public let emoji: [Emoji]
    }

    private static let probeSize: CGFloat = 16
    private static let emojiFont = "AppleColorEmoji"

    public let groups: [Group]
    private let byCharacter: [String: Emoji]

    public init(data: String, isDrawable: (String) -> Bool = Self.isDrawable) {
        var names: [String] = []
        var found: [[Emoji]] = []
        for line in data.split(separator: "\n") where !line.hasPrefix("#") {
            if line.hasPrefix("@") {
                names.append(String(line.dropFirst()))
                found.append([])
                continue
            }
            let columns = line.split(separator: "\t", omittingEmptySubsequences: false)
            var fields = columns.map(String.init).makeIterator()
            guard let character = fields.next(), let name = fields.next(),
                let keywords = fields.next(), let tone = fields.next(), !found.isEmpty,
                isDrawable(character)
            else { continue }
            found[found.count - 1].append(
                Emoji(
                    character: character, name: name, keywords: keywords, group: found.count - 1,
                    takesTone: !tone.isEmpty))
        }
        groups = zip(names, found).map(Group.init)
        byCharacter = Dictionary(found.joined().map { ($0.character, $0) }) { first, _ in first }
    }

    public static func bundled() -> Self? {
        guard let url = Bundle.module.url(forResource: "emoji", withExtension: "tsv"),
            let data = try? String(contentsOf: url, encoding: .utf8)
        else { return nil }
        return Self(data: data)
    }

    public static func isDrawable(_ emoji: String) -> Bool {
        let font = NSFont(name: emojiFont, size: probeSize)
        let text = NSAttributedString(string: emoji, attributes: [.font: font as Any])
        let line = CTLineCreateWithAttributedString(text)
        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun], runs.count == 1,
            let run = runs.first, CTRunGetGlyphCount(run) == 1
        else { return false }
        let attributes = CTRunGetAttributes(run) as? [NSAttributedString.Key: Any]
        return (attributes?[.font] as? NSFont)?.fontName == emojiFont
    }

    public func emoji(_ character: String) -> Emoji? {
        byCharacter[character]
    }

    public func search(_ text: String) -> [Emoji] {
        let query = Emoji.words(of: text)
        guard !query.isEmpty else { return [] }
        let ranked = groups.flatMap(\.emoji).enumerated().compactMap { index, emoji in
            emoji.match(query).map { match in (emoji, (match, emoji.nameWords.count, index)) }
        }
        return ranked.sorted { $0.1 < $1.1 }.map(\.0)
    }
}
