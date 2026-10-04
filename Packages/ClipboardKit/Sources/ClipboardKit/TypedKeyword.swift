public enum TypedKeyword: Equatable, Sendable {
    case arriving
    case changed
    case inPlace
    case unreadable

    public init(_ keyword: String, before text: String?, selecting: Bool) {
        guard !selecting else {
            self = .changed
            return
        }
        guard let text else {
            self = .unreadable
            return
        }
        let prefixes = keyword.indices.dropFirst().map { keyword[..<$0] }
        if text.hasSuffix(keyword) {
            self = .inPlace
        } else if keyword.count == 1 || prefixes.contains(where: { text.hasSuffix($0) }) {
            self = .arriving
        } else {
            self = .changed
        }
    }
}
