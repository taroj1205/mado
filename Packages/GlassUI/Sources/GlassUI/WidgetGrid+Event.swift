public import AppKit

extension WidgetGrid {
    public struct Event: Sendable, Equatable {
        public let title: String
        public let countdown: String
        public let detail: String
        public let colour: NSColor

        public init(title: String, countdown: String, detail: String, colour: NSColor) {
            self.title = title
            self.countdown = countdown
            self.detail = detail
            self.colour = colour
        }
    }
}
