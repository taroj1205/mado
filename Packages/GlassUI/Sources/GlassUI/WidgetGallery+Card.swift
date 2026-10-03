public import AppKit

extension WidgetGallery {
    public enum Size: Sendable {
        case small
        case wide
        case large

        private static let single = 1
        private static let double = 2
        private static let cell: CGFloat = 5
        private static let cellGap: CGFloat = 1.5
        private static let cellRadius: CGFloat = 1.2

        var title: String {
            switch self {
            case .small: "Small"
            case .wide: "Wide"
            case .large: "Large"
            }
        }

        var footprint: NSImage {
            let (across, down) =
                switch self {
                case .small: (Self.single, Self.single)
                case .wide: (Self.double, Self.single)
                case .large: (Self.double, Self.double)
                }
            let step = Self.cell + Self.cellGap
            let size = NSSize(
                width: CGFloat(across) * step - Self.cellGap,
                height: CGFloat(down) * step - Self.cellGap)
            let image = NSImage(size: size, flipped: false) { _ in
                NSColor.black.setFill()
                for column in 0..<across {
                    for row in 0..<down {
                        let square = NSRect(
                            x: CGFloat(column) * step, y: CGFloat(row) * step,
                            width: Self.cell, height: Self.cell)
                        NSBezierPath(
                            roundedRect: square, xRadius: Self.cellRadius, yRadius: Self.cellRadius
                        )
                        .fill()
                    }
                }
                return true
            }
            image.isTemplate = true
            return image
        }
    }

    public enum Group: CaseIterable, Sendable {
        case time
        case system
        case extensions

        var title: String {
            switch self {
            case .time: "Time"
            case .system: "System"
            case .extensions: "From extensions"
            }
        }

        var empty: (symbol: String, title: String) {
            switch self {
            case .time: ("clock", "No time widgets yet")
            case .system: ("cpu", "No system widgets yet")
            case .extensions: ("puzzlepiece.extension", "No widgets from extensions yet")
            }
        }
    }

    public struct Card {
        public let id: String
        public let name: String
        public let summary: String
        public let size: Size
        public let group: Group?
        public let symbol: String
        public let colour: NSColor

        public init(
            id: String, name: String, summary: String, size: Size, group: Group?, symbol: String,
            colour: NSColor
        ) {
            self.id = id
            self.name = name
            self.summary = summary
            self.size = size
            self.group = group
            self.symbol = symbol
            self.colour = colour
        }
    }
}
