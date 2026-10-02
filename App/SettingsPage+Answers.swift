import AppCore
import AppKit
import SearchKit

extension SettingsPage {
    private typealias Choice<Value> = (title: String, value: Value)

    private static let refreshes: [Choice<AnswerSettings.Refresh>] = [
        ("Every Hour", .hourly), ("Every 6 Hours", .sixHourly), ("Every Day", .daily),
        ("Manually", .manual),
    ]
    private static let english = Locale(identifier: "en_US")
    private static let ecb = "European Central Bank"

    static func answers(_ modules: ModuleManager?, _ rates: ExchangeRateFeed) -> [SettingsSection] {
        [
            SettingsSection(
                "Answers", note: "Shown as you type",
                AnswerSettings.Kind.allCases.map { kind in
                    .init(
                        kind.title, answerSwitch(kind, modules), example: kind.example,
                        detail: nil)
                }),
            SettingsSection(
                "Currency",
                [
                    .init("Default currency", currencyPopUp(modules, rates)),
                    .init(
                        "Update rates",
                        answerPopUp(
                            modules, \.refresh, choices: { [refreshes] },
                            then: { rates.interval = $0.seconds })),
                    .init(
                        "Exchange rates",
                        SettingsButton("Update Now") { try await rates.refresh() }, example: nil
                    ) { fetched(rates.rates) },
                ]),
            SettingsSection("Units when none is named", unitRows(modules)),
        ]
    }

    private static func unitRows(_ modules: ModuleManager?) -> [SettingsSection.Row] {
        [
            .init(
                "Temperature",
                answerPopUp(modules, \.temperature) {
                    let region = AnswerSettings.UnitSystem.temperature(in: .current)
                    return [
                        [("Follow Region (\(region == .metric ? "°C" : "°F"))", nil)],
                        [("Celsius (°C)", .metric), ("Fahrenheit (°F)", .usCustomary)],
                    ]
                }),
            .init(
                "Length, weight and volume",
                answerPopUp(modules, \.measures) {
                    let region = AnswerSettings.UnitSystem.measures(in: .current)
                    return [
                        [("Follow Region (\(region == .metric ? "Metric" : "US"))", nil)],
                        [("Metric", .metric), ("US", .usCustomary)],
                    ]
                }),
        ]
    }

    private static func fetched(_ rates: ExchangeRates?) -> String {
        guard let rates else { return "\(ecb) · not fetched yet" }
        let formatter = DateFormatter()
        formatter.locale = english
        formatter.dateFormat = "d MMM, h:mm a"
        return "\(ecb) · updated \(formatter.string(from: rates.fetched))"
    }

    private static func update(
        _ modules: ModuleManager?, _ change: (inout AnswerSettings) -> Void
    ) throws {
        var settings = AnswerSettings.load(from: modules)
        change(&settings)
        try modules?.setValue(settings, for: AnswerSettings.key)
    }

    private static func answerSwitch(
        _ kind: AnswerSettings.Kind, _ modules: ModuleManager?
    ) -> SettingsSwitch {
        let toggle = SettingsSwitch(
            read: { AnswerSettings.load(from: modules).shows(kind) },
            write: { shown in try update(modules) { $0.show(kind, shown) } })
        toggle.isEnabled = modules != nil
        return toggle
    }

    private static func currencyPopUp(
        _ modules: ModuleManager?, _ rates: ExchangeRateFeed
    ) -> SettingsPopUp {
        answerPopUp(modules, \.currency) {
            let region = Locale.current.currency?.identifier
            let chosen = AnswerSettings.load(from: modules).currency
            let codes = Set((rates.rates?.codes ?? []) + [chosen].compactMap(\.self)).sorted()
            return [
                [(region.map { "Follow Region (\($0))" } ?? "Follow Region", nil)],
                codes.map { code in
                    let name = english.localizedString(forCurrencyCode: code)
                    return (name.map { "\(code) · \($0)" } ?? code, code)
                },
            ]
        }
    }

    private static func answerPopUp<Value: Equatable>(
        _ modules: ModuleManager?, _ field: WritableKeyPath<AnswerSettings, Value>,
        choices: @escaping () -> [[Choice<Value>]], then changed: ((Value) -> Void)? = nil
    ) -> SettingsPopUp {
        let popUp = SettingsPopUp {
            let current = AnswerSettings.load(from: modules)[keyPath: field]
            return choices().map { section in
                SettingsPopUp.Section(
                    title: nil,
                    choices: section.map { title, value in
                        SettingsPopUp.Choice(title: title, isSelected: value == current) {
                            try update(modules) { $0[keyPath: field] = value }
                            changed?(value)
                        }
                    })
            }
        }
        popUp.isEnabled = modules != nil
        return popUp
    }
}

extension AnswerSettings.Kind {
    var title: String {
        switch self {
        case .calculator: "Calculator"
        case .units: "Units"
        case .currency: "Currency"
        case .timeZones: "Time zones"
        case .dates: "Dates & times"
        case .colours: "Colours"
        case .dictionary: "Dictionary"
        }
    }

    var example: String {
        switch self {
        case .calculator: "12 * (3 + 4)"
        case .units: "5 ft in cm"
        case .currency: "100 usd to nzd"
        case .timeZones: "3pm tokyo in auckland"
        case .dates: "45 days from today"
        case .colours: "#0A84FF"
        case .dictionary: "define ephemeral"
        }
    }
}
