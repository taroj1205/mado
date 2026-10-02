import AppCore
import Foundation
import Testing

@testable import SearchKit

@Suite struct AnswerSettingsTests {
    private static let xml = Data(
        """
        <Cube><Cube time='2026-10-01'>
        <Cube currency='USD' rate='1.25'/><Cube currency='JPY' rate='200'/>
        <Cube currency='NZD' rate='2'/>
        </Cube></Cube>
        """.utf8)

    private let rates: ExchangeRates
    private let newZealand = Locale(identifier: "en_NZ")

    init() throws {
        rates = try #require(ExchangeRates(ecb: Self.xml, fetched: .now))
    }

    private func answer(
        _ query: String, _ change: ((inout AnswerSettings) -> Void)? = nil
    ) -> Calculator.Answer? {
        var settings = AnswerSettings()
        change?(&settings)
        return Calculator.answer(for: query, rates: rates, settings: settings, region: newZealand)
    }

    @Test func everyAnswerIsOnAndEverythingFollowsTheRegionByDefault() {
        let settings = AnswerSettings()
        #expect(AnswerSettings.Kind.allCases.allSatisfy(settings.shows))
        #expect(settings.refresh == .sixHourly)
        #expect(settings.currency == nil)
        #expect(settings.temperature == nil)
        #expect(settings.measures == nil)
    }

    @Test func changedSettingsSurviveSavingAndLoading() throws {
        var answers = AnswerSettings()
        answers.show(.currency, false)
        answers.show(.dictionary, false)
        answers.currency = "JPY"
        answers.refresh = .manual
        answers.temperature = .usCustomary
        answers.measures = .metric
        let store = SettingsStore(
            url: FileManager.default.temporaryDirectory.appending(
                path: "\(UUID().uuidString)/settings.json"))
        defer { try? FileManager.default.removeItem(at: store.url.deletingLastPathComponent()) }
        var settings = Settings()
        try settings.setValue(answers, for: "answers")

        try store.save(settings)

        let loaded = try store.load().value(AnswerSettings.self, for: "answers")
        #expect(loaded == answers)
        #expect(loaded?.shows(.currency) == false)
        #expect(loaded?.shows(.units) == true)
    }

    @Test func turningAKindBackOnShowsItAgain() {
        var settings = AnswerSettings()
        settings.show(.units, false)
        settings.show(.units, true)
        #expect(settings == AnswerSettings())
    }

    @Test(arguments: [
        (AnswerSettings.Kind.calculator, "12 * (3 + 4)"),
        (.calculator, "15% of 240"),
        (.units, "5 ft in cm"),
        (.units, "5 ft + 5 cm"),
        (.units, "30 c"),
        (.currency, "100 usd to nzd"),
        (.timeZones, "3pm tokyo in auckland"),
        (.dates, "45 days from today"),
        (.dates, "2h 30m + 45m"),
    ])
    func aKindThatIsOffGivesNoAnswer(kind: AnswerSettings.Kind, query: String) {
        #expect(answer(query) != nil)
        #expect(answer(query) { $0.show(kind, false) } == nil)
    }

    @Test func turningOneKindOffLeavesTheOthers() {
        #expect(answer("12 * 3") { $0.show(.currency, false) }?.result == "36")
    }

    @Test func theDefaultCurrencyFollowsTheRegionUntilOneIsChosen() {
        #expect(answer("100 usd")?.result == "160.00 NZD")
        #expect(answer("100 usd") { $0.currency = "JPY" }?.result == "16,000 JPY")
    }

    @Test func anAmountAlreadyInTheDefaultCurrencyAnswersInUSD() {
        #expect(answer("100 jpy") { $0.currency = "JPY" }?.result == "0.62 USD")
    }

    @Test(arguments: [
        (AnswerSettings.UnitSystem.metric, "300 k", "26.85 °C"),
        (.usCustomary, "300 k", "80.33 °F"),
        (.metric, "30 c", "86 °F"),
        (.usCustomary, "86 f", "30 °C"),
    ])
    func aTemperatureWithNoTargetAnswersInTheChosenScaleOrTheOther(
        scale: AnswerSettings.UnitSystem, query: String, result: String
    ) {
        #expect(answer(query) { $0.temperature = scale }?.result == result)
    }

    @Test(arguments: [
        (AnswerSettings.UnitSystem.metric, "10 knots", "18.52 km/h"),
        (.usCustomary, "10 knots", "11.5078 mph"),
        (.metric, "5 ft", "1.524 m"),
        (.usCustomary, "5 ft", "1.524 m"),
        (.metric, "2 kg", "4.4092 lb"),
        (.usCustomary, "10 l", "2.6417 gal"),
        (.metric, "2 fl oz", "59.1471 ml"),
    ])
    func lengthWeightAndVolumeWithNoTargetAnswerInTheChosenSystemOrTheOther(
        system: AnswerSettings.UnitSystem, query: String, result: String
    ) {
        #expect(answer(query) { $0.measures = system }?.result == result)
    }

    @Test func followingTheRegionReadsTheLocale() {
        let american = Locale(identifier: "en_US")
        #expect(AnswerSettings().temperature(in: american) == .usCustomary)
        #expect(AnswerSettings().measures(in: american) == .usCustomary)
        #expect(AnswerSettings().temperature(in: newZealand) == .metric)
        #expect(AnswerSettings().measures(in: newZealand) == .metric)
        #expect(AnswerSettings().currency(in: newZealand) == "NZD")
        #expect(Calculator.answer(for: "300 k", region: american)?.result == "80.33 °F")
    }

    @Test(arguments: ["5 gb", "5 parsecs", "5 ft in", "5 ft 2"])
    func unitsWithNoCounterpartGiveNoAnswer(query: String) {
        #expect(answer(query) == nil)
    }
}
