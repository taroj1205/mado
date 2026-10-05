import AppKit

struct WidgetForm: Equatable {
    enum Reach: Int, Comparable {
        case narrow = 0
        case medium = 1
        case wide = 2

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    private static let mediumFrom: CGFloat = 150
    private static let wideFrom: CGFloat = 300
    private static let tallFrom: CGFloat = 120

    let reach: Reach
    let tall: Bool

    var isPlain: Bool {
        reach == .narrow && !tall
    }

    init(size: NSSize) {
        reach =
            if size.width >= Self.wideFrom {
                .wide
            } else if size.width >= Self.mediumFrom {
                .medium
            } else {
                .narrow
            }
        tall = size.height >= Self.tallFrom
    }
}
