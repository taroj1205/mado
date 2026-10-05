extension WidgetGrid {
    public struct Hour: Sendable, Equatable {
        public let label: String
        public let symbol: String
        public let value: String

        public init(label: String, symbol: String, value: String) {
            self.label = label
            self.symbol = symbol
            self.value = value
        }
    }

    public struct Fact: Sendable, Equatable {
        public let name: String
        public let value: String

        public init(name: String, value: String) {
            self.name = name
            self.value = value
        }
    }
}
