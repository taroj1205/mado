public import Foundation

extension ClipboardStore {
    private enum RetentionKey: CodingKey {
        case days
        case items
        case period
    }

    public struct Retention: Codable, Equatable, Sendable {
        public static let itemRange = 1...1_000_000
        public static let defaultPeriod = RetentionPeriod(defaultDays, .day)
        private static let defaultDays = 30

        public var period: RetentionPeriod?
        public var items: Int?

        public init(period: RetentionPeriod? = Self.defaultPeriod, items: Int? = 1_000) {
            self.period = period
            self.items = items
        }

        public init(from decoder: any Decoder) throws {
            let values = try decoder.container(keyedBy: RetentionKey.self)
            let saved = try? values.decode(RetentionPeriod.self, forKey: .period)
            let days = try? values.decode(Int.self, forKey: .days)
            let count = try? values.decode(Int.self, forKey: .items)
            self.init()
            if (try? values.decodeNil(forKey: .period)) == true {
                period = nil
            } else if let kept = saved ?? days.map({ RetentionPeriod($0, .day) }), kept.isValid {
                period = kept
            }
            if (try? values.decodeNil(forKey: .items)) == true {
                items = nil
            } else if let count, Self.itemRange.contains(count) {
                items = count
            }
        }

        public static func count(
            in text: String, within range: ClosedRange<Int>, locale: Locale = .current
        ) -> Int? {
            let formatter = NumberFormatter()
            formatter.locale = locale
            formatter.numberStyle = .decimal
            formatter.allowsFloats = false
            formatter.isLenient = false
            let number = formatter.number(from: text.trimmingCharacters(in: .whitespaces))
            return number.map(\.intValue).flatMap { range.contains($0) ? $0 : nil }
        }

        public func encode(to encoder: any Encoder) throws {
            var values = encoder.container(keyedBy: RetentionKey.self)
            try values.encode(period, forKey: .period)
            try values.encode(items, forKey: .items)
        }
    }
}
