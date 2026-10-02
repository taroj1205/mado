import Foundation

enum Currency {
    private static let locale = Locale(identifier: "en_US")
    private static let pluralAmount = 2.0
    private static let fallback = "USD"
    private static let fetchedFormat = "d MMM h:mm a"
    private static let aliases = [
        "$": "USD", "dollar": "USD", "dollars": "USD", "¥": "JPY", "円": "JPY", "yen": "JPY",
        "€": "EUR", "euro": "EUR", "euros": "EUR", "£": "GBP", "pound": "GBP", "pounds": "GBP",
        "won": "KRW", "yuan": "CNY",
    ]

    static func answer(
        for text: String, rates: ExchangeRates?, zone: TimeZone, home: String?
    ) -> Calculator.Answer? {
        guard let rates,
            let match = text.wholeMatch(
                of: /(?:([\$¥€£]) ?([\d.]+)|([\d.]+) ?([a-z円]+))(?: (?:to|in|as|->|=) ?(\S+))?/),
            let amount = Double(match.2 ?? match.3 ?? ""),
            let source = (match.1 ?? match.4).flatMap({ code(for: $0, in: rates) }),
            let target = match.5.map({ code(for: $0, in: rates) })
                ?? unnamedTarget(for: source, home: home, in: rates),
            target != source,
            let converted = rates.convert(amount, from: source, to: target), converted.isFinite
        else { return nil }
        let fetched = TimeZones.format(rates.fetched, fetchedFormat, in: zone)
        return Calculator.Answer(
            kind: "Currency", expression: "\(spelled(amount, source).amount) \(source)",
            expressionDetail: name(of: source),
            result: "\(spelled(converted, target).amount) \(target)",
            resultDetail: "\(name(of: target)) · \(fetched)")
    }

    private static func unnamedTarget(
        for source: String, home: String?, in rates: ExchangeRates
    ) -> String? {
        [home, fallback].compactMap(\.self).first { code in code != source && rates.has(code) }
    }

    private static func code(for token: Substring, in rates: ExchangeRates) -> String? {
        let code = aliases[String(token)] ?? token.uppercased()
        return rates.has(code) ? code : nil
    }

    private static func name(of code: String) -> String {
        Calculator.capitalized(spelled(pluralAmount, code).name)
    }

    private static func spelled(_ value: Double, _ code: String) -> (amount: String, name: String) {
        let words = value.formatted(.currency(code: code).presentation(.fullName).locale(locale))
            .split(maxSplits: 1, whereSeparator: \.isWhitespace)
        return (String(words.first ?? ""), String(words.last ?? ""))
    }
}
