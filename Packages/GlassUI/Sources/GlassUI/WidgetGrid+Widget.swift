extension WidgetGrid {
    public struct Widget: Sendable, Equatable {
        static let wideSpan = 2

        public let id: String
        public let name: String
        public let content: Content
        public let action: String
        public let spoken: String
        public let isWide: Bool
        var columns: Int?

        var span: Int {
            columns ?? narrowest
        }

        var narrowest: Int {
            isWide ? Self.wideSpan : 1
        }

        var track: Track? {
            if case .track(let playing) = content { playing } else { nil }
        }

        var isUnavailable: Bool {
            if case .unavailable = content { true } else { false }
        }

        public init(
            id: String, name: String, content: Content, action: String, spoken: String,
            isWide: Bool = false
        ) {
            self.id = id
            self.name = name
            self.content = content
            self.action = action
            self.spoken = spoken
            self.isWide = isWide
        }

        public init(
            id: String, name: String, value: String, detail: String, action: String,
            spoken: String, symbol: String? = nil, span: Span? = nil
        ) {
            self.init(
                id: id, name: name,
                content: .value(value, detail: detail, symbol: symbol, span: span),
                action: action, spoken: spoken)
        }

        public init(id: String, name: String, meters: [Meter], action: String, spoken: String) {
            self.init(
                id: id, name: name, content: .meters(meters), action: action, spoken: spoken)
        }

        public init(id: String, name: String, track: Track, action: String, spoken: String) {
            self.init(
                id: id, name: name, content: .track(track), action: action, spoken: spoken,
                isWide: true)
        }
    }
}
