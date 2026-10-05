extension WidgetGrid {
    public struct Widget: Sendable, Equatable {
        static let wideSpan = 2
        static let tallRows = 2

        public let id: String
        public let name: String
        public let content: Content
        public let action: String
        public let spoken: String
        public let isWide: Bool
        public let isTall: Bool
        public var hours: [Hour] = []
        public var facts: [Fact] = []
        var resized: Size?

        var smallest: Size {
            Size(
                columns: isWide ? Self.wideSpan : 1, rows: isTall ? Self.tallRows : 1)
        }

        var size: Size {
            resized ?? smallest
        }

        var track: Track? {
            if case .track(let playing) = content { playing } else { nil }
        }

        var railSize: Size {
            let columns = WidgetGrid.railColumns
            guard let resized else { return Size(columns: columns.widest, rows: size.rows) }
            return Size(
                columns: min(max(resized.columns, columns.narrowest), columns.widest),
                rows: resized.rows)
        }

        var isMonth: Bool {
            if case .month = content { true } else { false }
        }

        var isUnavailable: Bool {
            if case .unavailable = content { true } else { false }
        }

        public init(
            id: String, name: String, content: Content, action: String, spoken: String,
            isWide: Bool = false, isTall: Bool = false
        ) {
            self.id = id
            self.name = name
            self.content = content
            self.action = action
            self.spoken = spoken
            self.isWide = isWide
            self.isTall = isTall
        }

        public init(
            id: String, name: String, value: String, detail: String, action: String,
            spoken: String, symbol: String? = nil, span: Span? = nil, hours: [Hour] = [],
            facts: [Fact] = []
        ) {
            self.init(
                id: id, name: name,
                content: .value(value, detail: detail, symbol: symbol, span: span),
                action: action, spoken: spoken)
            self.hours = hours
            self.facts = facts
        }

        public init(
            id: String, name: String, meters: [Meter], action: String, spoken: String,
            facts: [Fact] = []
        ) {
            self.init(
                id: id, name: name, content: .meters(meters), action: action, spoken: spoken)
            self.facts = facts
        }

        public init(id: String, name: String, track: Track, action: String, spoken: String) {
            self.init(
                id: id, name: name, content: .track(track), action: action, spoken: spoken,
                isWide: true)
        }

        func usesFace(_ form: WidgetForm) -> Bool {
            switch content {
            case .value: form.tall || !hours.isEmpty || !facts.isEmpty
            case .meters: true
            default: false
            }
        }

        func size(in layout: Layout?) -> Size {
            layout == .strip ? Size(columns: size.columns) : size
        }
    }
}
