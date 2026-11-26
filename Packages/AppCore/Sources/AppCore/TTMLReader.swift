import Foundation

final class TTMLReader: NSObject, XMLParserDelegate {
    private enum Span {
        case word(text: String, time: TimeInterval, end: TimeInterval)
        case background
        case other
    }

    private static let secondsPerUnit = 60.0
    private static let wordTiming = "Word"
    private static let backgroundVocals = "x-bg"

    private(set) var isWordTimed = false
    private(set) var length: TimeInterval?
    private(set) var lines: [Lyrics.Line] = []
    private var inBody = false
    private var lineStart: TimeInterval?
    private var words: [Lyrics.Word] = []
    private var spans: [Span] = []

    private static func seconds(_ clock: String?) -> TimeInterval? {
        guard let parts = clock?.trimmingCharacters(in: ["s"]).split(separator: ":"),
            !parts.isEmpty
        else { return nil }
        let values = parts.compactMap { Double($0) }
        guard values.count == parts.count else { return nil }
        return values.reduce(0) { $0 * secondsPerUnit + $1 }
    }

    func parser(
        _: XMLParser, didStartElement element: String, namespaceURI _: String?,
        qualifiedName _: String?, attributes: [String: String]
    ) {
        switch element {
        case "tt":
            isWordTimed = attributes["itunes:timing"] == Self.wordTiming

        case "body":
            inBody = true
            length = Self.seconds(attributes["dur"])

        case "p" where inBody:
            lineStart = Self.seconds(attributes["begin"])
            words = []

        case "span" where lineStart != nil:
            spans.append(span(attributes))

        default:
            break
        }
    }

    private func span(_ attributes: [String: String]) -> Span {
        if attributes["ttm:role"] == Self.backgroundVocals || spans.contains(where: isBackground) {
            return .background
        }
        guard let time = Self.seconds(attributes["begin"]),
            let end = Self.seconds(attributes["end"])
        else { return .other }
        return .word(text: "", time: time, end: end)
    }

    private func isBackground(_ span: Span) -> Bool {
        if case .background = span { true } else { false }
    }

    func parser(_: XMLParser, foundCharacters string: String) {
        guard lineStart != nil else { return }
        switch spans.last {
        case let .word(text, time, end):
            spans[spans.count - 1] = .word(text: text + string, time: time, end: end)

        case nil where !words.isEmpty:
            let last = words.removeLast()
            words.append(.init(text: last.text + string, time: last.time, duration: last.duration))

        default:
            break
        }
    }

    func parser(
        _: XMLParser, didEndElement element: String, namespaceURI _: String?,
        qualifiedName _: String?
    ) {
        switch element {
        case "body":
            inBody = false

        case "span" where !spans.isEmpty:
            if case let .word(text, time, end) = spans.removeLast() {
                words.append(.init(text: text, time: time, duration: max(end - time, 0)))
            }

        case "p":
            let text = words.map(\.text).joined()
            if let lineStart, !text.allSatisfy(\.isWhitespace) {
                lines.append(.init(time: lineStart, text: text, words: words))
            }
            lineStart = nil

        default:
            break
        }
    }
}
