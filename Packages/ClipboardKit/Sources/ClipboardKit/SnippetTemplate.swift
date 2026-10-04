public import Foundation

public struct SnippetTemplate: Sendable {
    public struct Field: Equatable, Sendable {
        public let name: String
        public let options: [String]
    }

    public struct Values: Sendable {
        public var fields: [String: String]
        public var date: String
        public var time: String
        public var clipboard: String

        public init(fields: [String: String], date: String, time: String, clipboard: String) {
            self.fields = fields
            self.date = date
            self.time = time
            self.clipboard = clipboard
        }

        public static func now(fields: [String: String], clipboard: String) -> Self {
            let now = Date.now
            return Self(
                fields: fields, date: now.formatted(date: .abbreviated, time: .omitted),
                time: now.formatted(date: .omitted, time: .shortened), clipboard: clipboard)
        }
    }

    public struct Expansion: Equatable, Sendable {
        public let text: String
        public let caretBack: Int
        public let fieldRanges: [NSRange]
    }

    enum Part: Equatable, Sendable {
        case text(String)
        case date
        case time
        case clipboard
        case cursor
        case field(String)
    }

    private struct Token {
        let range: Range<String.Index>
        let part: Part
        let field: Field?
    }

    public static let fieldToken = #"{fill-in name="Name"}"#
    static let unnamedField = "Fill-in"

    let parts: [Part]
    public let fields: [Field]

    public init(_ text: String) {
        var found: [Part] = []
        var named: [Field] = []
        var start = text.startIndex
        for token in Self.tokens(in: text) {
            if token.range.lowerBound > start {
                found.append(.text(String(text[start..<token.range.lowerBound])))
            }
            found.append(token.part)
            if let field = token.field, !named.contains(where: { $0.name == field.name }) {
                named.append(field)
            }
            start = token.range.upperBound
        }
        if start < text.endIndex {
            found.append(.text(String(text[start...])))
        }
        parts = found
        fields = named
    }

    public static func tokenRanges(in text: String) -> [NSRange] {
        tokens(in: text).map { NSRange($0.range, in: text) }
    }

    private static func tokens(in text: String) -> [Token] {
        let token =
            #/
            \{ (?: (?<name> date|time|clipboard|cursor )
            | fill-in (?<attributes> (?: \s+ \w+ = "[^"]*" )* ) \s* ) \}
            /#
        return text.matches(of: token).map { match in
            if let name = match.output.name {
                return Token(range: match.range, part: placeholder(name), field: nil)
            }
            let parsed = field(String(match.output.attributes ?? ""))
            return Token(range: match.range, part: .field(parsed.name), field: parsed)
        }
    }

    private static func placeholder(_ name: Substring) -> Part {
        switch name {
        case "date": .date
        case "time": .time
        case "clipboard": .clipboard
        default: .cursor
        }
    }

    private static func field(_ attributes: String) -> Field {
        var values: [String: String] = [:]
        for match in attributes.matches(of: /(?<key>\w+)="(?<value>[^"]*)"/) {
            values[String(match.output.key)] = String(match.output.value)
        }
        let name = values["name"].map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        let options = (values["options"] ?? "").split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Field(name: name.isEmpty ? unnamedField : name, options: options)
    }

    public func expand(_ values: Values, scalars limit: Int = .max) -> Expansion {
        var text = ""
        var room = limit
        var caret: String?
        var ranges: [NSRange] = []
        @discardableResult
        func add(_ piece: String) -> NSRange {
            let kept = String(piece.unicodeScalars.prefix(room))
            let range = NSRange(location: text.utf16.count, length: kept.utf16.count)
            room -= kept.unicodeScalars.count
            text += kept
            return range
        }
        for part in parts.prefix(limit) {
            guard room > 0 else { break }
            switch part {
            case .text(let literal): add(literal)
            case .date: add(values.date)
            case .time: add(values.time)
            case .clipboard: add(values.clipboard)
            case .cursor: caret = caret ?? text
            case .field(let name): ranges.append(add(values.fields[name] ?? ""))
            }
        }
        return Expansion(
            text: text, caretBack: caret.map { text.count - $0.count } ?? 0, fieldRanges: ranges)
    }
}
