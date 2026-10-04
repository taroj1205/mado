import Foundation

public struct RetentionPeriod: Codable, Equatable, Sendable {
    public enum Unit: String, CaseIterable, Codable, Sendable {
        case day = "days"
        case week = "weeks"
        case month = "months"
        case year = "years"

        private static let mostDays = 3_650
        private static let mostWeeks = 520
        private static let mostMonths = 120
        private static let mostYears = 10

        public var range: ClosedRange<Int> {
            switch self {
            case .day: 1...Self.mostDays
            case .week: 1...Self.mostWeeks
            case .month: 1...Self.mostMonths
            case .year: 1...Self.mostYears
            }
        }

        var component: Calendar.Component {
            switch self {
            case .day: .day
            case .week: .weekOfYear
            case .month: .month
            case .year: .year
            }
        }
    }

    public let count: Int
    public let unit: Unit

    public var title: String {
        count == 1 ? "1 \(unit.rawValue.dropLast())" : "\(count.formatted()) \(unit.rawValue)"
    }

    var isValid: Bool {
        unit.range.contains(count)
    }

    public init(_ count: Int, _ unit: Unit) {
        self.count = count
        self.unit = unit
    }

    func start(before now: Date, in calendar: Calendar) -> Date? {
        calendar.date(byAdding: unit.component, value: -count, to: now)
    }
}
