import Foundation
import Testing

@testable import SearchKit

@Suite struct UsageTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func daysAgo(_ days: Double) -> Date {
        now.addingTimeInterval(-days * 24 * 60 * 60)
    }

    @Test func bonusGrowsWithUseAndHalvesEveryTwoWeeks() {
        var usage = Usage()
        #expect(usage.bonus(for: "safari", at: now) == 0)

        usage.record("safari", at: now)
        #expect(usage.bonus(for: "safari", at: now) == 8)
        #expect(usage.bonus(for: "safari", at: now.addingTimeInterval(Usage.halfLife)) == 5)

        usage.record("safari", at: now)
        usage.record("safari", at: now)
        #expect(usage.bonus(for: "safari", at: now) == 16)
    }

    @Test func ranksFixedHistoryByFrequencyAndRecency() {
        var usage = Usage()
        for _ in 0..<3 { usage.record("Safari", at: daysAgo(30)) }
        for _ in 0..<4 { usage.record("Spaces", at: daysAgo(2)) }
        usage.record("Speed Test", at: daysAgo(1))
        let names = ["Safari", "Spaces", "Speed Test", "Stocks"]

        let ranked = { (query: String) in
            Fuzzy.rank(names, by: query, bonus: { usage.bonus(for: $0, at: now) }, keys: { [$0] })
        }

        #expect(ranked("") == ["Spaces", "Speed Test", "Safari", "Stocks"])
        #expect(ranked("sa") == ["Spaces", "Safari"])
        #expect(Fuzzy.rank(names, by: "sa") { [$0] } == ["Safari", "Spaces"])
    }

    @Test func forgetsEntriesThatDecayedAway() {
        var usage = Usage()
        usage.record("old", at: daysAgo(70))
        usage.record("recent", at: daysAgo(50))

        usage.record("new", at: now)

        #expect(usage.entries.keys.sorted() == ["new", "recent"])
    }

    @Test func clockGoingBackDoesNotRaiseTheBonus() {
        var usage = Usage()
        usage.record("safari", at: now)

        #expect(usage.bonus(for: "safari", at: daysAgo(30)) == 8)
    }

    @Test func summarisesHowOftenAndWhenAnItemWasOpened() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Pacific/Auckland"))
        calendar.locale = Locale(identifier: "en_US")
        var usage = Usage()
        #expect(usage.summary(of: "safari", at: now, in: calendar) == nil)

        usage.record("safari", at: now)
        #expect(
            usage.summary(of: "safari", at: now, in: calendar)
                == "Opened 1 time · last today, 6:13\u{202F}PM")

        usage.record("safari", at: now)
        let tomorrow = now.addingTimeInterval(24 * 60 * 60)
        let later = now.addingTimeInterval(10 * 24 * 60 * 60)
        #expect(
            usage.summary(of: "safari", at: tomorrow, in: calendar)
                == "Opened 2 times · last yesterday, 6:13\u{202F}PM")
        #expect(
            usage.summary(of: "safari", at: later, in: calendar)
                == "Opened 2 times · last May 9, 6:13\u{202F}PM")

        usage.forget("safari")
        #expect(usage.summary(of: "safari", at: now, in: calendar) == nil)
    }

    @Test func estimatesTheCountOfEntriesSavedBeforeCountsExisted() throws {
        let json = #"{"entries":{"safari":{"weight":2.6,"date":800000000}}}"#

        let usage = try JSONDecoder().decode(Usage.self, from: Data(json.utf8))

        #expect(usage.entries["safari"] == Usage.Entry(weight: 2.6, date: now, count: 3))
    }

    @Test func survivesAJSONRoundTrip() throws {
        var usage = Usage()
        usage.record("safari", at: now)

        let decoded = try JSONDecoder().decode(Usage.self, from: JSONEncoder().encode(usage))

        #expect(decoded == usage)
    }
}
