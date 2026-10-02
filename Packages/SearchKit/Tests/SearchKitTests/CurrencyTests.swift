import Foundation
import Testing

@testable import SearchKit

@MainActor
@Suite struct CurrencyTests {
    private static let xml = Data(
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <gesmes:Envelope xmlns:gesmes="http://www.gesmes.org/xml/2002-08-01" \
        xmlns="http://www.ecb.int/vocabulary/2002-08-01/eurofxref">
        <gesmes:subject>Reference rates</gesmes:subject>
        <Cube><Cube time='2026-10-01'>
        <Cube currency='USD' rate='1.25'/><Cube currency='JPY' rate='200'/>
        <Cube currency='GBP' rate='0.8'/><Cube currency='NZD' rate='2'/>
        </Cube></Cube>
        </gesmes:Envelope>
        """.utf8)

    private let fetched: Date
    private let rates: ExchangeRates
    private let auckland: TimeZone
    private let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)

    init() throws {
        fetched = try Date("2026-10-02T03:19:00Z", strategy: .iso8601)
        rates = try #require(ExchangeRates(ecb: Self.xml, fetched: fetched))
        auckland = try #require(TimeZone(identifier: "Pacific/Auckland"))
    }

    @Test func theCanvasExampleFillsTheAnswerCardWithTheFetchTime() {
        #expect(
            Calculator.answer(for: "100 USD to NZD", local: auckland, rates: rates)
                == Calculator.Answer(
                    kind: "Currency", expression: "100.00 USD", expressionDetail: "US dollars",
                    result: "160.00 NZD", resultDetail: "New Zealand dollars · 2 Oct 4:19 PM"))
    }

    @Test(arguments: [
        ("$100", "160.00 NZD"), ("¥1000 in nzd", "10.00 NZD"), ("1000円", "10.00 NZD"),
        ("100 nzd", "62.50 USD"), ("100 euros to yen", "20,000 JPY"), ("1 gbp -> eur", "1.25 EUR"),
        ("£2.5 to usd", "3.91 USD"),
    ])
    func symbolsWordsAndCodesConvertIntoTheHomeCurrencyUnlessNamed(
        query: String, result: String
    ) {
        #expect(
            Currency.answer(for: query, rates: rates, zone: auckland, home: "NZD")?.result
                == result)
    }

    @Test func euroNamesAreCapitalised() {
        #expect(
            Currency.answer(for: "5 eur", rates: rates, zone: auckland, home: "NZD")?
                .expressionDetail == "Euros")
    }

    @Test(arguments: ["100 usd to usd", "100 xyz", "100 usd to xyz", "$100 usd", "usd", "5 m"])
    func unknownOrSameCurrenciesGiveNoAnswer(query: String) {
        #expect(Currency.answer(for: query, rates: rates, zone: auckland, home: "NZD") == nil)
    }

    @Test func noAnswerBeforeAnyRatesArrive() {
        #expect(Calculator.answer(for: "100 usd to nzd") == nil)
    }

    @Test func pagesThatAreNotECBRatesAreRejected() {
        #expect(ExchangeRates(ecb: Data("<html>Busy</html>".utf8), fetched: .now) == nil)
    }

    @Test func offlineTheFeedAnswersWithTheLastFetchedRates() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let cache = root.appending(path: "rates.xml")
        try Self.xml.write(to: cache)
        try FileManager.default.setAttributes(
            [.modificationDate: fetched], ofItemAtPath: cache.path(percentEncoded: false))
        let feed = ExchangeRateFeed(cache: cache, source: root.appending(path: "offline.xml"))

        feed.start(every: nil)
        await #expect(throws: URLError.self) { try await feed.refresh() }

        #expect(feed.rates == rates)
    }

    @Test func changingTheIntervalMovesTheNextFetch() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let cache = root.appending(path: "rates.xml")
        try Self.xml.write(to: cache)
        try FileManager.default.setAttributes(
            [.modificationDate: fetched], ofItemAtPath: cache.path(percentEncoded: false))
        let feed = ExchangeRateFeed(cache: cache, source: nil)

        feed.start(every: AnswerSettings.Refresh.sixHourly.seconds)
        #expect(feed.nextFetch == fetched.addingTimeInterval(21_600))

        feed.interval = AnswerSettings.Refresh.daily.seconds
        #expect(feed.nextFetch == fetched.addingTimeInterval(86_400))

        feed.interval = AnswerSettings.Refresh.manual.seconds
        #expect(feed.nextFetch == nil)
    }

    @Test func withoutCachedRatesTheFirstFetchIsDueAtOnce() {
        let feed = ExchangeRateFeed(cache: root.appending(path: "missing.xml"), source: nil)

        feed.start(every: AnswerSettings.Refresh.hourly.seconds)

        #expect(feed.nextFetch.map { $0 <= .now } == true)
    }

    @Test func aFailedFetchWaitsAFullIntervalBeforeTryingAgain() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let cache = root.appending(path: "rates.xml")
        try Self.xml.write(to: cache)
        let feed = ExchangeRateFeed(cache: cache, source: root.appending(path: "gone.xml"))
        feed.start(every: AnswerSettings.Refresh.hourly.seconds)
        let before = Date.now

        await #expect(throws: URLError.self) { try await feed.refresh() }

        #expect(feed.nextFetch.map { $0 >= before.addingTimeInterval(3_600) } == true)
    }

    @Test func aFetchReplacesTheRatesAndCachesThem() async throws {
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appending(path: "source.xml")
        try Self.xml.write(to: source)
        let cache = root.appending(path: "Mado/rates.xml")
        let feed = ExchangeRateFeed(cache: cache, source: source)
        var changes = 0
        feed.onChange = { changes += 1 }

        try await feed.refresh()

        #expect(changes == 1)
        #expect(feed.rates?.perEuro == rates.perEuro)
        #expect(ExchangeRates(contentsOf: cache)?.perEuro == rates.perEuro)
    }
}
