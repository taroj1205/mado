public import Foundation

public struct CalculatorHistory: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public let expression: String
        public let result: String
        public let kind: String
        public let date: Date
    }

    static let limit = 100

    public private(set) var entries: [Entry]

    public init() {
        entries = []
    }

    public mutating func record(
        expression: String, result: String, kind: String, at date: Date
    ) {
        entries.removeAll { $0.expression == expression }
        entries.insert(
            Entry(expression: expression, result: result, kind: kind, date: date), at: 0)
        entries = Array(entries.prefix(Self.limit))
    }

    func entries(matching query: String) -> [Entry] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return entries }
        return entries.filter { entry in
            entry.expression.localizedStandardContains(text)
                || entry.result.localizedStandardContains(text)
        }
    }

    public func days(
        matching query: String, calendar: Calendar
    ) -> [(day: Date, entries: [Entry])] {
        let days = Dictionary(grouping: entries(matching: query)) { entry in
            calendar.startOfDay(for: entry.date)
        }
        return days.keys.sorted(by: >).map { day in (day, days[day, default: []]) }
    }
}
