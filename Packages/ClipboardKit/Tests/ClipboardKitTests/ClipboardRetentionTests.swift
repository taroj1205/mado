import AppCore
import Foundation
import Testing

@testable import ClipboardKit

@Suite struct ClipboardRetentionTests {
    private typealias Retention = ClipboardStore.Retention

    private static let english = Locale(identifier: "en_US")
    private static let secondsPerDay: TimeInterval = 86_400

    private static func decode(_ json: String) throws -> Retention {
        try JSONDecoder().decode(ClipboardSettings.self, from: Data(json.utf8)).retention
    }

    @Test func readsLimitsSavedInDays() throws {
        let saved = try Self.decode(#"{"retention": {"days": 7, "items": 100}}"#)
        let year = try Self.decode(#"{"retention": {"days": 365, "items": 10000}}"#)
        let resaved = try JSONDecoder().decode(
            ClipboardSettings.self, from: JSONEncoder().encode(["retention": saved])
        ).retention

        #expect(saved == Retention(period: .init(7, .day), items: 100))
        #expect(year == Retention(period: .init(365, .day), items: 10_000))
        #expect(resaved == saved)
    }

    @Test func keepsForeverUnlimitedAndCustomLimitsAcrossSaves() throws {
        let limits = [
            Retention(period: nil, items: nil),
            Retention(period: .init(3, .month), items: 2_500),
            Retention(period: .init(2, .week), items: nil),
            Retention(period: nil, items: 1_000_000),
        ]
        for retention in limits {
            var settings = ClipboardSettings()
            settings.retention = retention
            var stored = Settings()
            try stored.setValue(settings, for: "clipboard")

            let restored = try stored.value(ClipboardSettings.self, for: "clipboard")

            #expect(restored?.retention == retention)
        }
        let json = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(Retention(period: nil, items: nil)))
        let saved = try #require(json as? [String: Any])
        #expect(saved.keys.sorted() == ["items", "period"])
        #expect(saved.values.allSatisfy { $0 is NSNull })
    }

    @Test func fallsBackToTheDefaultForLimitsOutOfRange() throws {
        let saved = [
            #"{"retention": {"period": {"count": 0, "unit": "weeks"}, "items": 0}}"#,
            #"{"retention": {"period": {"count": 11, "unit": "years"}, "items": 1000001}}"#,
            #"{"retention": {"period": {"count": 3, "unit": "fortnights"}, "items": "lots"}}"#,
            #"{"retention": {"days": 3651}}"#,
        ]

        for json in saved {
            #expect(try Self.decode(json) == Retention())
        }
    }

    @Test func namesPeriodsInTheirUnits() {
        let periods: [RetentionPeriod] = [
            .init(1, .day), .init(45, .day), .init(1, .week), .init(2, .week), .init(1, .month),
            .init(6, .month), .init(1, .year), .init(10, .year),
        ]

        #expect(
            periods.map(\.title) == [
                "1 day", "45 days", "1 week", "2 weeks", "1 month", "6 months", "1 year",
                "10 years",
            ])
    }

    @Test func readsWholeNumbersWithinTheRange() {
        let range = 1...10_000
        let typed = ["2,500", " 45 ", "10,000", "2.5", "abc", "12abc", "0", "-3", "10,001", ""]

        let counts = typed.map { Retention.count(in: $0, within: range, locale: Self.english) }

        #expect(counts == [2_500, 45, 10_000, nil, nil, nil, nil, nil, nil, nil])
    }

    @Test func letsEachUnitReachAboutTenYears() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let calendar = Calendar(identifier: .gregorian)

        let starts = RetentionPeriod.Unit.allCases.compactMap { unit in
            RetentionPeriod(unit.range.upperBound, unit).start(before: now, in: calendar)
        }
        let days = starts.map { now.timeIntervalSince($0) / Self.secondsPerDay }

        #expect(RetentionPeriod.Unit.allCases.allSatisfy { $0.range.lowerBound == 1 })
        #expect(days.count == RetentionPeriod.Unit.allCases.count)
        #expect(days.allSatisfy { (3_640...3_653).contains($0) })
    }
}
