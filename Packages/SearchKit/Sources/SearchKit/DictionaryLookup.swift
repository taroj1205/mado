import CoreServices
public import Foundation

public enum DictionaryLookup {
    public struct Entry: Sendable, Equatable {
        public let headword: String
        public let pronunciation: String
        public let partOfSpeech: String
        public let definition: String
        public let similar: [String]
        public let opposite: [String]
        public let dictionary: String
        public let url: URL
        public let japaneseURL: URL?
    }

    static let similarLimit = 5
    static let japaneseID = "com.apple.dictionary.ja.Daijirin"
    private static let kana: ClosedRange<UInt32> = 0x3040...0x30FF
    private static let questionMarks = CharacterSet(charactersIn: "?？")

    public static func term(in query: String) -> String? {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = text.wholeMatch(of: /define\s+(.+)/.ignoresCase()) {
            let term = match.1.trimmingCharacters(in: questionMarks.union(.whitespaces))
            return term.isEmpty ? nil : term
        }
        guard let last = text.unicodeScalars.last, questionMarks.contains(last) else { return nil }
        let word = text.dropLast()
        guard word.contains(where: \.isLetter), !word.contains(where: \.isWhitespace) else {
            return nil
        }
        return String(word)
    }

    public static func query(for word: String, replacing query: String) -> String {
        let defining = query.wholeMatch(of: /\s*define\s.*/.ignoresCase()) != nil
        return defining || word.contains(where: \.isWhitespace) ? "define \(word)" : "\(word)?"
    }

    public static func entry(for term: String) -> Entry? {
        guard let services = DictionaryServices.shared else { return plainEntry(for: term) }
        return services.entry(for: term)
    }

    static func plainEntry(for term: String) -> Entry? {
        let range = CFRange(location: 0, length: term.utf16.count)
        guard
            let text = unsafe DCSCopyTextDefinition(nil, term as CFString, range)?
                .takeRetainedValue()
        else { return nil }
        return Entry(
            headword: term, pronunciation: "", partOfSpeech: "", definition: text as String,
            similar: [], opposite: [], dictionary: "", url: lookupURL(for: term),
            japaneseURL: nil)
    }

    static func lookupURL(for term: String) -> URL {
        let path = term.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        return URL(string: "dict://\(path)") ?? URL(filePath: "/System/Applications/Dictionary.app")
    }

    static func sentence(_ sense: String) -> String {
        let text = sense.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = text.last else { return text }
        let capital = text.prefix(1).uppercased() + text.dropFirst()
        return last.isPunctuation ? capital : capital + "."
    }

    static func pronunciation(_ text: String) -> String {
        let japanese = text.unicodeScalars.contains { kana.contains($0.value) }
        return text.isEmpty || japanese ? text : "/\(text)/"
    }

    static func relations(in xhtml: String) -> (similar: [String], opposite: [String]) {
        let sensePath = "(//*[\(hasClass("msThes")) or \(hasClass("msDict"))])[1]"
        guard let document = try? XMLDocument(xmlString: xhtml),
            let sense = try? document.nodes(forXPath: sensePath).first
        else { return ([], []) }
        func words(_ path: String) -> [String] {
            ((try? sense.nodes(forXPath: path)) ?? []).compactMap { node in
                let text = node.children?.first { $0.kind == .text }?.stringValue ?? ""
                let word = text.trimmingCharacters(in: .whitespacesAndNewlines)
                return word.isEmpty ? nil : word
            }
        }
        return (
            Array(words(".//*[\(hasClass("syn"))]").prefix(similarLimit)),
            words(".//*[\(hasClass("ant"))] | .//a[@type='対義語']")
        )
    }

    private static func hasClass(_ name: String) -> String {
        "contains(concat(' ', normalize-space(@class), ' '), ' \(name) ')"
    }
}
