public enum TypedKeyword: Equatable, Sendable {
    case arriving
    case changed
    case inPlace
    case unreadable

    public init(_ keyword: String, before text: String?) {
        guard let text else {
            self = .unreadable
            return
        }
        if text.hasSuffix(keyword) {
            self = .inPlace
        } else if text.hasSuffix(String(keyword.dropLast())) {
            self = .arriving
        } else {
            self = .changed
        }
    }
}
