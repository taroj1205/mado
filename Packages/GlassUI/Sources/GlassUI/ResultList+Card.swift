public import AppKit

extension ResultList {
    public struct Section: Sendable, Equatable {
        public let title: String
        public let items: [Item]
        public let notice: Notice?
        public let card: Card?
        public let colour: ColourCard?

        public init(
            title: String, items: [Item], notice: Notice? = nil, card: Card? = nil,
            colour: ColourCard? = nil
        ) {
            self.title = title
            self.items = items
            self.notice = notice
            self.card = card
            self.colour = colour
        }
    }

    public struct Word: Sendable, Equatable {
        public let title: String
        public let query: String

        public init(title: String, query: String) {
            self.title = title
            self.query = query
        }
    }

    public struct Card: Sendable, Equatable {
        public let title: String
        public let detail: String
        public let text: String
        public let similar: [Word]
        public let opposite: [String]

        public init(
            title: String, detail: String, text: String, similar: [Word], opposite: [String]
        ) {
            self.title = title
            self.detail = detail
            self.text = text
            self.similar = similar
            self.opposite = opposite
        }
    }

    public struct ColourCard: Sendable, Equatable {
        public let swatch: NSColor
        public let hex: String
        public let rgb: String
        public let hsl: String
        public let closest: String
        public let onWhite: String
        public let onBlack: String

        public init(
            swatch: NSColor, hex: String, rgb: String, hsl: String, closest: String,
            onWhite: String, onBlack: String
        ) {
            self.swatch = swatch
            self.hex = hex
            self.rgb = rgb
            self.hsl = hsl
            self.closest = closest
            self.onWhite = onWhite
            self.onBlack = onBlack
        }
    }
}
