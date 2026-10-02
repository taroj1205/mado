import Foundation
import Testing

@testable import SearchKit

@Suite struct CalculatorHistoryTests {
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func dropsTheOldestPastTheLimit() {
        var history = CalculatorHistory()
        for index in 0...CalculatorHistory.limit {
            history.record(
                expression: "\(index) + 1", result: "\(index + 1)", kind: "Calculator",
                at: start.addingTimeInterval(Double(index)))
        }

        #expect(history.entries.count == CalculatorHistory.limit)
        #expect(history.entries.first?.expression == "\(CalculatorHistory.limit) + 1")
        #expect(history.entries.last?.expression == "1 + 1")
        #expect(!history.entries.contains { $0.expression == "0 + 1" })
    }

    @Test func repeatingASumMovesItToTheTop() {
        var history = CalculatorHistory()
        history.record(expression: "2 × 3", result: "6", kind: "Calculator", at: start)
        history.record(
            expression: "5 ft", result: "152.4 cm", kind: "Units", at: start.addingTimeInterval(1))
        history.record(
            expression: "2 × 3", result: "6", kind: "Calculator", at: start.addingTimeInterval(2))

        #expect(history.entries.map(\.expression) == ["2 × 3", "5 ft"])
        #expect(history.entries.first?.date == start.addingTimeInterval(2))
    }

    @Test func filtersBySumOrAnswerInOrder() {
        var history = CalculatorHistory()
        history.record(expression: "12 × 12", result: "144", kind: "Calculator", at: start)
        history.record(
            expression: "100 USD", result: "167.42 NZD", kind: "Currency",
            at: start.addingTimeInterval(1))
        history.record(
            expression: "1 + 1", result: "2", kind: "Calculator", at: start.addingTimeInterval(2))

        #expect(history.entries(matching: " ").count == 3)
        #expect(history.entries(matching: "nzd").map(\.expression) == ["100 USD"])
        #expect(
            history.entries(matching: "1").map(\.expression) == ["1 + 1", "100 USD", "12 × 12"])
    }

    @Test func groupsByDayNewestFirst() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Pacific/Auckland"))
        let today = calendar.startOfDay(for: start)
        let yesterday = try #require(calendar.date(byAdding: .day, value: -1, to: today))
        var history = CalculatorHistory()
        history.record(
            expression: "1 + 1", result: "2", kind: "Calculator",
            at: yesterday.addingTimeInterval(60))
        history.record(expression: "2 + 2", result: "4", kind: "Calculator", at: today)
        history.record(
            expression: "3 + 3", result: "6", kind: "Calculator", at: today.addingTimeInterval(60))

        let days = history.days(matching: "", calendar: calendar)
        #expect(days.map(\.day) == [today, yesterday])
        #expect(days.map { $0.entries.map(\.expression) } == [["3 + 3", "2 + 2"], ["1 + 1"]])
        #expect(history.days(matching: "4", calendar: calendar).map(\.entries.count) == [1])
    }
}
