public import Foundation

public enum TextTool: String, CaseIterable, Sendable {
    case base64Decode = "base64_decode"
    case base64Encode = "base64_encode"
    case formatJSON = "format_json"
    case lowercase = "lowercase"
    case removeDuplicateLines = "remove_duplicate_lines"
    case sortLines = "sort_lines"
    case titleCase = "title_case"
    case trimWhitespace = "trim_whitespace"
    case uppercase = "uppercase"
    case urlDecode = "url_decode"
    case urlEncode = "url_encode"

    public enum Outcome: Equatable, Sendable {
        case changed(String)
        case invalid
        case unchanged

        public var output: String? {
            if case .changed(let output) = self { output } else { nil }
        }
    }

    public struct Counts: Equatable, Sendable {
        public let lines: Int
        public let words: Int
        public let characters: Int

        public init(of text: String) {
            lines = TextTool.lines(of: text).count
            words = ClipboardStore.Entry.Counts(of: text) { false }.words
            characters = text.count
        }
    }

    public static let allCases: [Self] = [
        .removeDuplicateLines, .sortLines, .titleCase, .uppercase, .lowercase, .trimWhitespace,
        .urlEncode, .urlDecode, .base64Encode, .base64Decode, .formatJSON,
    ]
    private static let previewLimit = 200
    private static let lineJoin = " · "
    private static let urlSafe = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    private static let base64Block = 4

    public var title: String {
        switch self {
        case .removeDuplicateLines: "Remove Duplicate Lines"
        case .sortLines: "Sort Lines"
        case .titleCase: "Title Case"
        case .uppercase: "UPPERCASE"
        case .lowercase: "lowercase"
        case .trimWhitespace: "Trim Whitespace"
        case .urlEncode: "URL Encode"
        case .urlDecode: "URL Decode"
        case .base64Encode: "Base64 Encode"
        case .base64Decode: "Base64 Decode"
        case .formatJSON: "Format JSON"
        }
    }

    public var symbol: String {
        switch self {
        case .removeDuplicateLines, .sortLines: "arrow.up.arrow.down"
        case .titleCase, .uppercase, .lowercase: "textformat"
        case .trimWhitespace: "text.alignleft"
        case .urlEncode, .urlDecode: "link"
        case .base64Encode, .base64Decode: "chevron.left.forwardslash.chevron.right"
        case .formatJSON: "curlybraces"
        }
    }

    private var unchangedSummary: String {
        switch self {
        case .removeDuplicateLines: "No duplicate lines"
        case .sortLines: "Already sorted"
        case .titleCase: "Already Title Case"
        case .uppercase: "Already uppercase"
        case .lowercase: "Already lowercase"
        case .trimWhitespace: "Nothing to trim"
        case .urlEncode, .base64Encode: "Nothing to encode"
        case .urlDecode, .base64Decode: "Nothing to decode"
        case .formatJSON: "Already formatted"
        }
    }

    private var invalidSummary: String {
        switch self {
        case .urlDecode: "Not URL-encoded"
        case .formatJSON: "Not JSON"
        default: "Not Base64"
        }
    }

    private var transform: (String) -> String? {
        switch self {
        case .removeDuplicateLines: Self.withoutDuplicateLines
        case .sortLines: Self.sortedLines
        case .titleCase: \.capitalized
        case .uppercase: { $0.uppercased() }
        case .lowercase: { $0.lowercased() }
        case .trimWhitespace: { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        case .urlEncode: { $0.addingPercentEncoding(withAllowedCharacters: Self.urlSafe) }
        case .urlDecode: \.removingPercentEncoding
        case .base64Encode: { Data($0.utf8).base64EncodedString() }
        case .base64Decode: Self.base64Decoded
        case .formatJSON: Self.formattedJSON
        }
    }

    static func lines(of text: String) -> [Substring] {
        let body = text.hasSuffix("\n") ? text.dropLast() : Substring(text)
        return body.split(separator: "\n", omittingEmptySubsequences: false)
    }

    public static func duplicateLines(in text: String) -> IndexSet {
        var seen = Set<Substring>()
        var duplicates = IndexSet()
        for (index, line) in lines(of: text).enumerated() where !line.isEmpty {
            if !seen.insert(line).inserted {
                duplicates.insert(index)
            }
        }
        return duplicates
    }

    private static func rejoin(_ lines: [Substring], like text: String) -> String {
        lines.joined(separator: "\n") + (text.hasSuffix("\n") ? "\n" : "")
    }

    private static func withoutDuplicateLines(_ text: String) -> String {
        let duplicates = duplicateLines(in: text)
        let kept = lines(of: text).enumerated().filter { !duplicates.contains($0.offset) }
        return rejoin(kept.map(\.element), like: text)
    }

    private static func sortedLines(_ text: String) -> String {
        let sorted = lines(of: text).sorted { first, second in
            first.localizedStandardCompare(second) == .orderedAscending
        }
        return rejoin(sorted, like: text)
    }

    private static func base64Decoded(_ text: String) -> String? {
        var digits = String(text.filter { !$0.isWhitespace })
            .replacing("-", with: "+").replacing("_", with: "/")
        let remainder = digits.count % base64Block
        if remainder != 0 {
            digits += String(repeating: "=", count: base64Block - remainder)
        }
        return Data(base64Encoded: digits).flatMap { String(bytes: $0, encoding: .utf8) }
    }

    private static func formattedJSON(_ text: String) -> String? {
        let object = try? JSONSerialization.jsonObject(with: Data(text.utf8))
        guard object is [Any] || object is [String: Any] else { return nil }
        return JSONIndenter(text).output
    }

    public func apply(to text: String) -> Outcome {
        guard let output = transform(text) else { return .invalid }
        return output == text ? .unchanged : .changed(output)
    }

    public func summary(of outcome: Outcome, from text: String) -> String {
        switch outcome {
        case .unchanged: return unchangedSummary

        case .invalid: return invalidSummary

        case .changed(let output):
            switch self {
            case .removeDuplicateLines:
                return "\(Self.lines(of: text).count) lines → \(Self.lines(of: output).count)"

            case .sortLines:
                return "A → Z"

            default:
                return String(output.trimmingCharacters(in: .newlines).prefix(Self.previewLimit))
                    .replacing("\n", with: Self.lineJoin)
            }
        }
    }
}
