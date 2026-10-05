import Foundation

private typealias Function = @Sendable ([Double]) -> Double?

extension Calculator {
    struct Parser {
        private static let maxDepth = 64
        private static let maxFactorial = 170.0
        private static let maxRoundingDigits = 15.0
        private static let percentDivisor = 100.0
        private static let decimalBase = 10.0
        private static let halfTurn = 180.0
        private static let unary = 1
        private static let binary = 2
        private static let shown = ["*": "×", "x": "×", "/": "÷"]
        private static let constants = ["pi": Double.pi, "π": Double.pi, "e": M_E]
        private static let functions: [String: Function] = [
            "log": logarithm, "log10": each(log10), "log2": each(log2), "ln": each(log),
            "exp": each(exp), "sqrt": each(sqrt), "cbrt": each(cbrt), "abs": each { abs($0) },
            "sin": each(sin), "cos": each(cos), "tan": each(tan), "asin": each(asin),
            "acos": each(acos), "atan": each(atan), "sinh": each(sinh), "cosh": each(cosh),
            "tanh": each(tanh), "floor": each(floor), "ceil": each(ceil), "trunc": each(trunc),
            "rad": each { $0 * .pi / halfTurn }, "deg": each { $0 * halfTurn / .pi },
            "round": rounded, "min": { $0.min() }, "max": { $0.max() },
            "pow": { $0.count == binary ? pow($0[0], $0[1]) : nil },
        ]

        var pretty: String {
            var text = ""
            var position = 0
            while position < characters.count {
                let length = operators[position] ?? 1
                let piece = String(characters[position..<position + length])
                if implicit.contains(position) { text += " × " }
                if operators[position] != nil {
                    text += " \(Self.shown[piece] ?? piece) "
                } else if piece == "," {
                    text += ", "
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
        private var implicit: Set<Int> = []
        private var percentTerm = false

        init(_ text: String) {
            characters = Array(text)
        }

        private static func each(_ transform: @escaping @Sendable (Double) -> Double) -> Function {
            { $0.count == unary ? transform($0[0]) : nil }
        }

        private static func logarithm(_ values: [Double]) -> Double? {
            switch values.count {
            case unary: log10(values[0])
            case binary: log(values[0]) / log(values[1])
            default: nil
            }
        }

        private static func rounded(_ values: [Double]) -> Double? {
            guard let value = values.first else { return nil }
            guard values.count == binary else {
                return values.count == unary ? value.rounded() : nil
            }
            let digits = values[1]
            guard digits == digits.rounded(), abs(digits) <= maxRoundingDigits else { return nil }
            let scale = pow(decimalBase, digits)
            return (value * scale).rounded() / scale
        }

        private static func isExponent(_ character: Character) -> Bool {
            character == "e" || character == "+" || character == "-"
                || (character.isASCII && character.isNumber)
        }

        private static func isNameCharacter(_ character: Character) -> Bool {
            character.isLetter || (character.isASCII && character.isNumber)
        }

        private static func apply(_ symbol: String?, _ lhs: Double, _ rhs: Double) -> Double {
            switch symbol {
            case "/", "÷": lhs / rhs
            case "off": rhs * (1 - lhs)
            case "mod": lhs.truncatingRemainder(dividingBy: rhs)
            default: lhs * rhs
            }
        }

        private static func factorial(of value: Double) -> Double? {
            guard (0...maxFactorial).contains(value), value == value.rounded() else { return nil }
            return (0..<Int(value)).reduce(1) { product, step in product * Double(step + 1) }
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
            while true {
                let symbol = takeOperator(["off", "of", "mod", "*", "x", "×", "/", "÷"])
                guard symbol != nil || startsOperand() else { return value }
                if symbol == nil { implicit.insert(index) }
                guard let rhs = signed() else { return nil }
                value = Self.apply(symbol, value, rhs)
                percentTerm = false
            }
        }

        private mutating func startsOperand() -> Bool {
            guard let next = skipSpaces() else { return false }
            return next == "(" || next.isLetter
        }

        private mutating func signed() -> Double? {
            guard depth < Self.maxDepth else { return nil }
            depth += 1
            defer { depth -= 1 }
            guard let sign = take(["+", "-"]) else { return power() }
            return signed().map { sign == "-" ? -$0 : $0 }
        }

        private mutating func power() -> Double? {
            guard let base = postfix() else { return nil }
            guard takeOperator(["^"]) != nil else { return base }
            let exponent = signed()
            percentTerm = false
            return exponent.map { pow(base, $0) }
        }

        private mutating func postfix() -> Double? {
            guard var value = atom() else { return nil }
            percentTerm = false
            while let mark = take(["%", "!", "°"]) {
                percentTerm = mark == "%"
                switch mark {
                case "%": value /= Self.percentDivisor

                case "°": value *= .pi / Self.halfTurn

                default:
                    guard let factorial = Self.factorial(of: value) else { return nil }
                    value = factorial
                }
            }
            return value
        }

        private mutating func atom() -> Double? {
            if take(["("]) != nil {
                guard let value = sum(), take([")"]) != nil else { return nil }
                return value
            }
            if skipSpaces()?.isLetter == true { return named() }
            let digits = characters[index...].prefix { $0.isASCII && ($0.isNumber || $0 == ".") }
            index += digits.count
            let exponent =
                String(characters[index...].prefix(while: Self.isExponent))
                .prefixMatch(of: /e[+-]?\d+/)?.0 ?? ""
            index += exponent.count
            return Double(String(digits) + exponent)
        }

        private mutating func named() -> Double? {
            let word = characters[index...].prefix(while: Self.isNameCharacter)
            index += word.count
            let name = String(word)
            if let constant = Self.constants[name] { return constant }
            guard let function = Self.functions[name], take(["("]) != nil else { return nil }
            let values = arguments()
            percentTerm = false
            return values.isEmpty ? nil : function(values)
        }

        private mutating func arguments() -> [Double] {
            var values: [Double] = []
            repeat {
                guard let value = sum() else { return [] }
                values.append(value)
            } while take([","]) != nil
            return take([")"]) != nil ? values : []
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
}
