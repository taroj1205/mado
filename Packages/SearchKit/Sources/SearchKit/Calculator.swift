import Foundation

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
        private static let shown: [Character: String] = ["*": "×", "x": "×", "/": "÷"]

        var pretty: String {
            characters.indices.reduce(into: "") { text, index in
                let character = characters[index]
                guard !character.isWhitespace else { return }
                let symbol = Self.shown[character] ?? String(character)
                text += binaryOperators.contains(index) ? " \(symbol) " : symbol
            }
        }

        private let characters: [Character]
        private var index = 0
        private var depth = 0
        private var binaryOperators: Set<Int> = []

        init(_ text: String) {
            characters = Array(text)
        }

        mutating func parse() -> Double? {
            guard let value = sum(), skipSpaces() == nil else { return nil }
            return value
        }

        private mutating func sum() -> Double? {
            guard var value = product() else { return nil }
            while let symbol = takeOperator(["+", "-"]) {
                guard let rhs = product() else { return nil }
                value = symbol == "+" ? value + rhs : value - rhs
            }
            return value
        }

        private mutating func product() -> Double? {
            guard var value = signed() else { return nil }
            while let symbol = takeOperator(["*", "x", "×", "/", "÷"]) {
                guard let rhs = signed() else { return nil }
                value = symbol == "/" || symbol == "÷" ? value / rhs : value * rhs
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
            return signed().map { pow(base, $0) }
        }

        private mutating func percent() -> Double? {
            guard var value = atom() else { return nil }
            while take(["%"]) != nil {
                value /= 100
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

        private mutating func takeOperator(_ symbols: Set<Character>) -> Character? {
            guard let symbol = take(symbols) else { return nil }
            binaryOperators.insert(index - 1)
            return symbol
        }
    }

    private static let locale = Locale(identifier: "en_US")
    private static let fractionDigits = 4
    private static let smallFractionDigits = 6
    private static let spelledLimit = 1e12
    private static let spelledPrecision = 10_000.0
    private static let operators: Set<Character> = [
        "+", "-", "*", "/", "×", "÷", "x", "^", "%", "(",
    ]
    private static let operatorWords = [
        "+": "plus", "-": "minus", "*": "times", "x": "times", "×": "times",
        "/": "divided by", "÷": "divided by",
    ]

    public static func answer(for query: String) -> Answer? {
        let text = query.lowercased()
            .replacing(/(\d),(?=\d{3})/) { "\($0.1)" }
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard text.drop(while: { $0 == "-" }).contains(where: operators.contains) else {
            return nil
        }
        return portion(text) ?? change(text) ?? maths(text)
    }

    static func format(_ value: Double) -> String {
        let digits = abs(value) < 1 ? smallFractionDigits : fractionDigits
        return value.formatted(.number.locale(locale).precision(.fractionLength(0...digits)))
    }

    static func words(for value: Double) -> String? {
        guard abs(value) < spelledLimit else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .spellOut
        return formatter.string(for: (value * spelledPrecision).rounded() / spelledPrecision)
    }

    private static func portion(_ text: String) -> Answer? {
        guard let match = text.wholeMatch(of: /(?:what is )?(-?[\d.]+) ?% (of|off) (-?[\d.]+)/),
            let percent = Double(match.1), let total = Double(match.3)
        else { return nil }
        let off = match.2 == "off"
        return answer(
            "Percentage", expression: "\(match.1)% \(match.2) \(format(total))",
            detail: off ? "Discount" : "Part of a total",
            value: total * (off ? 1 - percent / 100 : percent / 100))
    }

    private static func change(_ text: String) -> Answer? {
        guard let match = text.wholeMatch(of: /(-?[\d.]+) ?([+-]) ?([\d.]+) ?%/),
            let base = Double(match.1), let percent = Double(match.3)
        else { return nil }
        let increase = match.2 == "+"
        return answer(
            "Percentage", expression: "\(format(base)) \(match.2) \(format(percent))%",
            detail: increase ? "Increase" : "Decrease",
            value: base * (increase ? 1 + percent / 100 : 1 - percent / 100))
    }

    private static func maths(_ text: String) -> Answer? {
        var parser = Parser(text)
        guard let value = parser.parse() else { return nil }
        return answer(
            "Calculator", expression: parser.pretty, detail: spelled(text) ?? "Expression",
            value: value)
    }

    private static func spelled(_ text: String) -> String? {
        let compact = text.filter { !$0.isWhitespace }
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

    private static func capitalized(_ text: String) -> String {
        text.prefix(1).uppercased() + text.dropFirst()
    }
}
