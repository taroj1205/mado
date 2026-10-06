extension WidgetGrid {
    public struct Size: Hashable, Sendable, Codable {
        private static let double = 2
        private static let separator = "x"
        private static let parts = 2

        public static let small = Self(columns: 1)
        public static let wide = Self(columns: double)
        static let large = Self(columns: double, rows: double)
        static let extraLarge = Self(columns: double * double, rows: double)
        static let named = [small, wide, large, extraLarge]

        private static let names: [Self: String] = [
            small: "Small", wide: "Medium", large: "Large", extraLarge: "Extra Large",
        ]

        public let columns: Int
        public let rows: Int

        public var dimensions: String {
            "\(columns) × \(rows)"
        }

        var name: String? {
            Self.names[self]
        }

        var rowsTitle: String {
            rows == 1 ? "1 row" : "\(rows) rows"
        }

        public var title: String {
            name.map { "\($0) · \(dimensions)" } ?? dimensions
        }

        public init(columns: Int, rows: Int = 1) {
            self.columns = columns
            self.rows = rows
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let legacy = try? container.decode(Int.self) {
                self.init(columns: legacy)
                return
            }
            let text = try container.decode(String.self)
            let numbers = text.split(separator: Self.separator).compactMap { Int($0) }
            guard numbers.count == Self.parts, let across = numbers.first, let down = numbers.last
            else {
                throw DecodingError.dataCorruptedError(
                    in: container, debugDescription: "Unknown widget size \(text)")
            }
            self.init(columns: across, rows: down)
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode("\(columns)\(Self.separator)\(rows)")
        }
    }
}
