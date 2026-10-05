public import AppKit

extension ResultList {
    public struct WidgetHour: Sendable, Equatable {
        public let label: String
        public let symbol: String
        public let value: String

        public init(label: String, symbol: String, value: String) {
            self.label = label
            self.symbol = symbol
            self.value = value
        }
    }

    public struct WidgetLine: Sendable, Equatable {
        public let time: String
        public let title: String
        public let colour: NSColor

        public init(time: String, title: String, colour: NSColor) {
            self.time = time
            self.title = title
            self.colour = colour
        }
    }

    public enum WidgetBody: Sendable, Equatable {
        case forecast(symbol: String, value: String, detail: String, hours: [WidgetHour])
        case meters([WidgetGrid.Meter])
        case events([WidgetLine])
        case message(headline: String, detail: String)
    }

    public struct WidgetCard: Sendable, Equatable {
        public let body: WidgetBody
        public let spoken: String

        public init(body: WidgetBody, spoken: String) {
            self.body = body
            self.spoken = spoken
        }
    }
}
