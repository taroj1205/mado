public enum LyricsSide: String, CaseIterable, Sendable {
    case leading = "left"
    case trailing = "right"

    public var title: String {
        self == .leading ? "Left" : "Right"
    }

    public var other: Self {
        self == .leading ? .trailing : .leading
    }
}
