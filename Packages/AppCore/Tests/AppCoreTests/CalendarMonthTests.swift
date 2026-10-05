import Foundation
import Testing

@testable import AppCore

@Suite struct CalendarMonthTests {
    @Test func theMonthFillsWholeWeeksAndMarksToday() throws {
        let month = try #require(CalendarMonth(around: date(2_026, 9, 30), calendar: calendar(2)))
        #expect(month.title == "September 2026")
        #expect(month.weekdays == ["M", "T", "W", "T", "F", "S", "S"])
        #expect(month.days.count == 35)
        #expect(month.days.first == .init(number: "31", isInMonth: false, isToday: false))
        #expect(month.days[1] == .init(number: "1", isInMonth: true, isToday: false))
        #expect(month.days[30] == .init(number: "30", isInMonth: true, isToday: true))
        #expect(month.days[31...].map(\.number) == ["1", "2", "3", "4"])
        #expect(month.days.filter(\.isToday).count == 1)
        #expect(month.days.count { $0.isInMonth } == 30)
    }

    @Test func weeksStartOnTheCalendarsFirstWeekday() throws {
        let month = try #require(CalendarMonth(around: date(2_026, 9, 1), calendar: calendar(1)))
        #expect(month.weekdays == ["S", "M", "T", "W", "T", "F", "S"])
        #expect(month.days.prefix(3).map(\.number) == ["30", "31", "1"])
        #expect(month.days.count == 35)
    }

    @Test func aMonthAcrossSixWeeksShowsAllOfThem() throws {
        let month = try #require(CalendarMonth(around: date(2_026, 8, 10), calendar: calendar(2)))
        #expect(month.days.count == 42)
        #expect(month.days.first?.number == "27")
        #expect(month.days.last?.number == "6")
    }

    private func calendar(_ firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_NZ")
        calendar.timeZone = TimeZone(identifier: "Pacific/Auckland") ?? .gmt
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar(2).date(from: DateComponents(year: year, month: month, day: day, hour: 9))
            ?? .distantPast
    }
}
