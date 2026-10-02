public import Foundation

public enum Calculator {
    public struct Answer: Sendable, Equatable {
        public let kind: String
        public let expression: String
        public let expressionDetail: String
        public let result: String
        public let resultDetail: String
    }

    struct Parser {
        private static let maxDepth = 64
        private static let shown = ["*": "×", "x": "×", "/": "÷"]

        var pretty: String {
            var text = ""
            var position = 0
            while position < characters.count {
                let length = operators[position] ?? 1
                let piece = String(characters[position..<position + length])
                if operators[position] != nil {
                    text += " \(Self.shown[piece] ?? piece) "
                } else if !piece.allSatisfy(\.isWhitespace) {
                    text += piece
                }
                position += length
            }
            return text
        }

        private let characters: [Character]
        private var index = 0
        private var depth = 0
        private var operators: [Int: Int] = [:]
        private var percentTerm = false

        init(_ text: String) {
            characters = Array(text)
        }

        mutating func parse() -> Double? {
            guard let value = sum(), skipSpaces() == nil else { return nil }
            return value
        }

        private mutating func sum() -> Double? {
            guard var value = product() else { return nil }
            var percentSoFar = percentTerm
            while let symbol = takeOperator(["+", "-"]) {
                guard let rhs = product() else { return nil }
                let change = percentTerm && !percentSoFar ? value * rhs : rhs
                value = symbol == "+" ? value + change : value - change
                percentSoFar = percentSoFar && percentTerm
            }
            return value
        }

        private mutating func product() -> Double? {
            guard var value = signed() else { return nil }
            while let symbol = takeOperator(["off", "of", "*", "x", "×", "/", "÷"]) {
                guard let rhs = signed() else { return nil }
                switch symbol {
                case "/", "÷": value /= rhs
                case "off": value = rhs * (1 - value)
                default: value *= rhs
                }
                percentTerm = false
            }
            return value
        }

        private mutating func signed() -> Double? {
            guard depth < Self.maxDepth else { return nil }
            depth += 1
            defer { depth -= 1 }
            guard let sign = take(["+", "-"]) else { return power() }
            return signed().map { sign == "-" ? -$0 : $0 }
        }

        private mutating func power() -> Double? {
            guard let base = percent() else { return nil }
            guard takeOperator(["^"]) != nil else { return base }
            let exponent = signed()
            percentTerm = false
            return exponent.map { pow(base, $0) }
        }

        private mutating func percent() -> Double? {
            guard var value = atom() else { return nil }
            percentTerm = false
            while take(["%"]) != nil {
                value /= 100
                percentTerm = true
            }
            return value
        }

        private mutating func atom() -> Double? {
            if take(["("]) != nil {
                guard let value = sum(), take([")"]) != nil else { return nil }
                return value
            }
            skipSpaces()
            let digits = characters[index...].prefix { $0.isASCII && ($0.isNumber || $0 == ".") }
            index += digits.count
            return Double(String(digits))
        }

        @discardableResult
        private mutating func skipSpaces() -> Character? {
            while index < characters.count, characters[index].isWhitespace {
                index += 1
            }
            return index < characters.count ? characters[index] : nil
        }

        private mutating func take(_ symbols: Set<Character>) -> Character? {
            guard let next = skipSpaces(), symbols.contains(next) else { return nil }
            index += 1
            return next
        }

        private mutating func takeOperator(_ symbols: [String]) -> String? {
            skipSpaces()
            guard let symbol = symbols.first(where: { characters[index...].starts(with: $0) })
            else { return nil }
            operators[index] = symbol.count
            index += symbol.count
            return symbol
        }
    }

    private static let locale = Locale(identifier: "en_US")
    private static let fractionDigits = 4
    private static let smallFractionDigits = 6
    private static let spelledLimit = 1e12
    private static let spelledPrecision = 10_000.0
    private static let triggers: Set<Character> = [
        "+", "-", "*", "/", "×", "÷", "x", "^", "%", "(",
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
        let text = query.lowercased()
            .replacing(/(\d),(?=\d{3})/) { "\($0.1)" }
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

    private static func arithmetic(_ text: String) -> Answer? {
        guard text.drop(while: { $0 == "-" }).contains(where: triggers.contains) else {
            return nil
        }
        var parser = Parser(text)
        guard let value = parser.parse() else { return nil }
        let compact = text.filter { !$0.isWhitespace }
        let percentage = percentageDetail(compact)
        return answer(
            percentage == nil ? "Calculator" : "Percentage", expression: parser.pretty,
            detail: percentage ?? spelled(compact) ?? "Expression", value: value)
    }

    static func format(_ value: Double) -> String {
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
