public import AppKit

extension WidgetGrid {
    public struct Span: Sendable, Equatable {
        public let low: String
        public let high: String
        public let position: Double
        public let cold: NSColor
        public let warm: NSColor

        public init(low: String, high: String, position: Double, cold: NSColor, warm: NSColor) {
            self.low = low
            self.high = high
            self.position = position
            self.cold = cold
            self.warm = warm
        }
    }
}
