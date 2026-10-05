public import Foundation

public enum Calculator {
    public struct Answer: Sendable, Equatable {
        public let kind: String
        public let expression: String
        public let expressionDetail: String
        public let result: String
        public let resultDetail: String
    }

    private static let locale = Locale(identifier: "en_US")
    private static let fractionDigits = 4
    private static let smallFractionDigits = 6
    private static let spelledLimit = 1e12
    private static let groupedLimit = 1e15
    private static let scientificDigits = 5
    private static let spelledPrecision = 10_000.0
    private static let triggers: Set<Character> = [
        "+", "-", "*", "/", "×", "÷", "x", "^", "%", "(", "!", "°",
    ]
    private static let spoken = [
        (#"\s+to the power of\s+"#, "^"), (#"\s*squared\b"#, "^2"), (#"\s*cubed\b"#, "^3"),
        (#"\s+plus\s+"#, "+"), (#"\s+minus\s+"#, "-"),
        (#"\s+(?:times|multiplied by)\s+"#, "*"), (#"\s+divided by\s+"#, "/"),
        (#"\s*percent\b"#, "%"), (#"(\d)\s*deg(?:rees?)?\b"#, "$1°"),
        (#"square root of ([\d.]+)"#, "sqrt($1)"), (#"cube root of ([\d.]+)"#, "cbrt($1)"),
    ]
    private static let operatorWords = [
        "+": "plus", "-": "minus", "*": "times", "x": "times", "×": "times",
        "/": "divided by", "÷": "divided by",
    ]

    public static func answer(
        for query: String, now: Date = .now, local: TimeZone = .current,
        rates: ExchangeRates? = nil, settings: AnswerSettings = AnswerSettings(),
        region: Locale = .current
    ) -> Answer? {
        let lowered = query.lowercased()
        let text =
            (lowered.contains(/[a-z]\(/)
            ? lowered : lowered.replacing(/(\d),(?=\d{3})/) { "\($0.1)" })
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .replacing(/^what is\s/, with: "")
        let home = settings.currency(in: region)
        let answers: [(AnswerSettings.Kind, () -> Answer?)] = [
            (.units, { Conversion.answer(for: text) }),
            (.timeZones, { TimeZones.answer(for: text, now: now, local: local) }),
            (.dates, { TimeMath.answer(for: text, now: now, local: local) }),
            (.units, { Conversion.maths(for: text) }),
            (.units, { Conversion.answer(for: text, preferring: settings, in: region) }),
            (.currency, { Currency.answer(for: text, rates: rates, zone: local, home: home) }),
            (.calculator, { arithmetic(text) }),
        ]
        for (kind, answer) in answers where settings.shows(kind) {
            if let found = answer() { return found }
        }
        return nil
    }

    private static func arithmetic(_ query: String) -> Answer? {
        let text = symbols(in: query)
        guard
            text.drop(while: { $0 == "-" }).contains(where: triggers.contains)
                || text.contains(" mod ") || text.contains(/\d ?(?:pi|π)\b/)
        else { return nil }
        var parser = Parser(text)
        guard let value = parser.parse() else { return nil }
        let compact = text.filter { !$0.isWhitespace }
        let percentage = percentageDetail(compact)
        return answer(
            percentage == nil ? "Calculator" : "Percentage", expression: parser.pretty,
            detail: percentage ?? spelled(compact) ?? "Expression", value: value)
    }

    private static func symbols(in text: String) -> String {
        spoken.reduce(text) { text, rule in
            text.replacingOccurrences(of: rule.0, with: rule.1, options: .regularExpression)
        }
    }

    static func format(_ value: Double) -> String {
        if abs(value) >= groupedLimit {
            var style = FloatingPointFormatStyle<Double>.number.locale(locale)
            style = style.notation(.scientific).precision(.significantDigits(1...scientificDigits))
            return value.formatted(style)
        }
        let digits = abs(value) < 1 ? smallFractionDigits : fractionDigits
        let normalized = value == 0 ? 0 : value
        return normalized.formatted(.number.locale(locale).precision(.fractionLength(0...digits)))
    }

    static func words(for value: Double) -> String? {
        guard abs(value) < spelledLimit else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .spellOut
        return formatter.string(for: (value * spelledPrecision).rounded() / spelledPrecision)
    }

    private static func percentageDetail(_ compact: String) -> String? {
        if let match = compact.wholeMatch(of: /-?[\d.]+%(of|off)-?[\d.]+/) {
            return match.1 == "off" ? "Discount" : "Part of a total"
        }
        guard let match = compact.wholeMatch(of: /-?[\d.]+([+-])[\d.]+%/) else { return nil }
        return match.1 == "+" ? "Increase" : "Decrease"
    }

    private static func spelled(_ compact: String) -> String? {
        guard let match = compact.wholeMatch(of: /(-?[\d.]+)([-+*\/x×÷])([\d.]+)/),
            let lhs = Double(match.1).flatMap(words), let rhs = Double(match.3).flatMap(words),
            let name = operatorWords[String(match.2)]
        else { return nil }
        return capitalized("\(lhs) \(name) \(rhs)")
    }

    private static func answer(
        _ kind: String, expression: String, detail: String, value: Double
    ) -> Answer? {
        guard value.isFinite else { return nil }
        let result = value == 0 ? 0 : value
        return Answer(
            kind: kind, expression: expression, expressionDetail: detail,
            result: format(result), resultDetail: words(for: result).map(capitalized) ?? "Result")
    }

    static func capitalized(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }
}
