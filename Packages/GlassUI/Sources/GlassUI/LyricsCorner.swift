public enum LyricsCorner: String, CaseIterable, Sendable {
    case bottomLeading = "bottom_leading"
    case bottomTrailing = "bottom_trailing"
    case topLeading = "top_leading"
    case topTrailing = "top_trailing"

    var isTop: Bool {
        self == .topLeading || self == .topTrailing
    }

    var isLeading: Bool {
        self == .topLeading || self == .bottomLeading
    }

    var name: String {
        "\(isTop ? "top" : "bottom") \(isLeading ? "left" : "right")"
    }

    init(top: Bool, leading: Bool) {
        self =
            switch (top, leading) {
            case (true, true): .topLeading
            case (true, false): .topTrailing
            case (false, true): .bottomLeading
            case (false, false): .bottomTrailing
            }
    }
}
