public import Foundation

public struct SettingsSearch: Codable, Equatable, Sendable {
    public struct Place: Hashable, Sendable {
        public let page: String
        public let tab: String?

        public var title: String {
            tab.map { "\(page)\(SettingsSearch.separator)\($0)" } ?? page
        }

        public init(page: String, tab: String?) {
            self.page = page
            self.tab = tab
        }
    }

    public struct Entry: Equatable, Sendable {
        public let id: String
        public let place: Place
        public let section: String?
        public let label: String
        public let keywords: [String]
        public let choices: [String]
        public let isHotkey: Bool

        public init(
            id: String, place: Place, section: String?, label: String, keywords: [String] = [],
            choices: [String] = [], isHotkey: Bool = false
        ) {
            self.id = id
            self.place = place
            self.section = section
            self.label = label
            self.keywords = keywords
            self.choices = choices
            self.isHotkey = isHotkey
        }
    }

    public struct Text: Equatable, Sendable {
        public let string: String
        public let matches: [Int]

        public init(string: String, matches: [Int]) {
            self.string = string
            self.matches = matches
        }
    }

    public struct Suggestion: Equatable, Sendable {
        public let entry: String
        public let place: Place
        public let title: Text
        public let note: Text?
        public let matchedChoice: Bool
    }

    public struct Group: Equatable, Sendable {
        public let place: Place
        public let title: Text
        public let isSelectable: Bool
        public let suggestions: [Suggestion]
    }

    private struct Option {
        let score: Int
        let title: Text
        let note: Text?
        var isChoice = false
    }

    private struct Scored {
        let suggestion: Suggestion
        let score: Int
    }

    static let recentLimit = 5
    private static let separator = " › "
    private static let alsoPrefix = "Also “"
    private static let alsoSuffix = "”"
    private static let hotkeyWords = ["hotkey", "shortcut"]
    private static let keptPerLetter = 5
    private static let strongPerLetter = 6
    private static let labelBonus = 24
    private static let keywordBonus = 12
    private static let sectionBonus = 4
    private static let placeBonus = 40

    public private(set) var recent: [String]
    private var usage: Usage

    public init() {
        recent = []
        usage = Usage()
    }

    private static func noted(
        _ entry: Entry, plain: Text, match: (String) -> Fuzzy.Match?
    ) -> [Option] {
        let words = entry.keywords.compactMap { word in
            match(word).map { found in
                let note = Text(
                    string: alsoPrefix + word + alsoSuffix,
                    matches: found.offsets.map { $0 + alsoPrefix.count })
                return Option(score: found.score + keywordBonus, title: plain, note: note)
            }
        }
        let choices = entry.choices.compactMap { choice in
            match(choice).map { found in
                Option(
                    score: found.score, title: plain,
                    note: Text(string: choice, matches: found.offsets), isChoice: true)
            }
        }
        return words + choices
    }

    public func groups(
        for query: String, in entries: [Entry], places: [Place], at now: Date
    ) -> [Group] {
        let length = Fuzzy.Key(query.trimmingCharacters(in: .whitespacesAndNewlines)).letters.count
        guard length > 0 else { return [] }
        var found: [Place: [Scored]] = [:]
        for entry in entries {
            if let scored = best(entry, query: query, length: length, at: now) {
                found[entry.place, default: []].append(scored)
            }
        }
        var headers: [Place: Option] = [:]
        for place in places where headers[place] == nil {
            headers[place] = header(place, query: query, length: length)
        }
        let order = Dictionary(places.enumerated().map { ($1, $0) }) { first, _ in first }
        return Set(found.keys).union(headers.keys)
            .map { place in
                let rows = (found[place] ?? []).enumerated()
                    .sorted { ($1.element.score, $0.offset) < ($0.element.score, $1.offset) }
                    .map(\.element)
                let header = headers[place]
                let group = Group(
                    place: place,
                    title: header?.title ?? Text(string: place.title, matches: []),
                    isSelectable: header != nil, suggestions: rows.map(\.suggestion))
                let score = max(rows.first?.score ?? 0, header?.score ?? 0)
                return (group: group, score: score, order: order[place] ?? places.count)
            }
            .sorted { ($1.score, $0.order) < ($0.score, $1.order) }
            .map(\.group)
    }

    public func recentSuggestions(in entries: [Entry]) -> [Suggestion] {
        recent.compactMap { id in
            entries.first { $0.id == id }.map { entry in
                Suggestion(
                    entry: entry.id, place: entry.place,
                    title: Text(string: entry.label, matches: []),
                    note: Text(string: entry.place.title, matches: []), matchedChoice: false)
            }
        }
    }

    public mutating func visit(_ id: String, at now: Date) {
        usage.record(id, at: now)
        recent = Array(([id] + recent.filter { $0 != id }).prefix(Self.recentLimit))
    }

    public mutating func forget(_ id: String) {
        recent.removeAll { $0 == id }
    }

    public mutating func clearRecent() {
        recent = []
    }

    private func best(_ entry: Entry, query: String, length: Int, at now: Date) -> Scored? {
        let match = { (text: String) -> Fuzzy.Match? in
            guard let found = Fuzzy.match(query, in: text),
                found.score >= length * Self.keptPerLetter
            else { return nil }
            return found
        }
        let plain = Text(string: entry.label, matches: [])
        var options: [Option] = []
        if let found = match(entry.label) {
            let strong = found.score >= length * Self.strongPerLetter
            let title = Text(string: entry.label, matches: found.offsets)
            let score = found.score + (strong ? Self.labelBonus : 0)
            options.append(Option(score: score, title: title, note: nil))
        }
        options += Self.noted(entry, plain: plain, match: match)
        let hidden =
            (entry.isHotkey ? Self.hotkeyWords.map { ($0, Self.keywordBonus) } : [])
            + [entry.section].compactMap(\.self).map { ($0, Self.sectionBonus) }
        for (word, bonus) in hidden {
            guard let found = match(word) else { continue }
            options.append(Option(score: found.score + bonus, title: plain, note: nil))
        }
        guard let top = options.max(by: { $0.score < $1.score }) else { return nil }
        let suggestion = Suggestion(
            entry: entry.id, place: entry.place, title: top.title, note: top.note,
            matchedChoice: top.isChoice)
        let bonus = usage.bonus(for: entry.id, at: now)
        return Scored(suggestion: suggestion, score: top.score + bonus)
    }

    private func header(_ place: Place, query: String, length: Int) -> Option? {
        let name = place.tab ?? place.page
        guard let found = Fuzzy.match(query, in: name),
            found.score >= length * Self.strongPerLetter
        else { return nil }
        let lead = place.tab == nil ? 0 : place.page.count + Self.separator.count
        let title = Text(string: place.title, matches: found.offsets.map { $0 + lead })
        return Option(score: found.score + Self.placeBonus, title: title, note: nil)
    }
}
