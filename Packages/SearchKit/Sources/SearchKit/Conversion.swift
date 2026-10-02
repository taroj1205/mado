import Foundation

enum Conversion {
    private typealias Keyed = (key: Substring, unit: Named)

    private struct Named {
        let keys: [String]
        let unit: Dimension
        let name: String

        init(_ keys: [String], _ unit: Dimension, _ name: String) {
            self.keys = keys
            self.unit = unit
            self.name = name
        }
    }

    private struct UnitSum {
        private static let shownSymbols = ["*": "×", "/": "÷"]

        private(set) var shown: [String] = []
        private(set) var names: [String] = []
        private(set) var first: Keyed?
        private var running = 0.0
        private var sign = 1.0
        private var term: (value: Double, hasUnit: Bool)?
        private var pending: String?
        private var operations = 0
        private var afterNumber = false
        private var lastHadUnit = false

        mutating func read(symbol: Substring?, number: Substring?, key: Substring?) -> Bool {
            if let symbol { return add(String(symbol)) }
            guard let value = number.flatMap({ Double($0) }) else { return false }
            guard let key else { return add(value, nil) }
            return named(key).map { add(value, (key, $0)) } ?? false
        }

        mutating func total() -> Double? {
            guard afterNumber, operations > 0, closeTerm() else { return nil }
            return running
        }

        private mutating func add(_ symbol: String) -> Bool {
            guard afterNumber else { return false }
            afterNumber = false
            let shownSymbol = Self.shownSymbols[symbol] ?? symbol
            shown.append(shownSymbol)
            guard symbol == "+" || symbol == "-" else {
                pending = shownSymbol
                return true
            }
            guard closeTerm() else { return false }
            sign = symbol == "+" ? 1 : -1
            return true
        }

        private mutating func add(_ number: Double, _ unit: Keyed?) -> Bool {
            if afterNumber {
                guard lastHadUnit, unit != nil, closeTerm() else { return false }
            }
            guard use(unit) else { return false }
            afterNumber = true
            lastHadUnit = unit != nil
            shown.append(Calculator.format(number) + (unit.map { " \($0.key)" } ?? ""))
            let value = unit?.unit.unit.converter.baseUnitValue(fromValue: number) ?? number
            return combine(value, hasUnit: unit != nil)
        }

        private mutating func use(_ unit: Keyed?) -> Bool {
            guard let unit else { return true }
            guard !(unit.unit.unit is UnitTemperature),
                first.map({ sameDimension($0.unit, unit.unit) }) ?? true
            else { return false }
            first = first ?? unit
            if !names.contains(unit.unit.name) { names.append(unit.unit.name) }
            return true
        }

        private mutating func combine(_ value: Double, hasUnit: Bool) -> Bool {
            guard let current = term else {
                term = (value, hasUnit)
                return true
            }
            switch pending {
            case "×" where !(current.hasUnit && hasUnit):
                term = (current.value * value, current.hasUnit || hasUnit)

            case "÷" where !hasUnit:
                term = (current.value / value, current.hasUnit)

            default:
                return false
            }
            pending = nil
            operations += 1
            return true
        }

        private mutating func closeTerm() -> Bool {
            guard let term, term.hasUnit else { return false }
            running += sign * term.value
            self.term = nil
            operations += 1
            return true
        }
    }

    private static let pound = 0.45359237
    private static let ounce = 0.028349523125
    private static let stone = 6.35029318
    private static let gallon = 3.785411784
    private static let fluidOunce = 0.0295735295625
    private static let cup = 0.2365882365
    private static let tablespoon = 0.01478676478125
    private static let teaspoon = 0.00492892159375
    private static let kilometrePerHour = 0.2777777777777778
    private static let knot = 0.5144444444444445
    private static let temperatureDigits = 100.0
    private static let britishEnglish = Locale(identifier: "en_GB")

    private static let units = [
        Named(["mm"], UnitLength.millimeters, "Millimetres"),
        Named(["cm"], UnitLength.centimeters, "Centimetres"),
        Named(["m"], UnitLength.meters, "Metres"),
        Named(["km"], UnitLength.kilometers, "Kilometres"),
        Named(["in", "inch", "inches"], UnitLength.inches, "Inches"),
        Named(["ft", "foot", "feet"], UnitLength.feet, "Feet"),
        Named(["yd"], UnitLength.yards, "Yards"),
        Named(["mi", "mile", "miles"], UnitLength.miles, "Miles"),
        Named(["g"], UnitMass.grams, "Grams"),
        Named(["kg"], UnitMass.kilograms, "Kilograms"),
        Named(["lb", "lbs"], UnitMass(symbol: "lb", converter: linear(pound)), "Pounds"),
        Named(["oz"], UnitMass(symbol: "oz", converter: linear(ounce)), "Ounces"),
        Named(["st"], UnitMass(symbol: "st", converter: linear(stone)), "Stone"),
        Named(["ml"], UnitVolume.milliliters, "Millilitres"),
        Named(["l", "litre", "litres"], UnitVolume.liters, "Litres"),
        Named(["cup", "cups"], UnitVolume(symbol: "cup", converter: linear(cup)), "Cups (US)"),
        Named(["tbsp"], UnitVolume(symbol: "tbsp", converter: linear(tablespoon)), "Tablespoons"),
        Named(["tsp"], UnitVolume(symbol: "tsp", converter: linear(teaspoon)), "Teaspoons"),
        Named(["gal"], UnitVolume(symbol: "gal", converter: linear(gallon)), "Gallons (US)"),
        Named(
            ["fl oz"], UnitVolume(symbol: "fl oz", converter: linear(fluidOunce)), "Fluid ounces"),
        Named(
            ["kmh", "km/h"], UnitSpeed(symbol: "km/h", converter: linear(kilometrePerHour)),
            "Kilometres per hour"),
        Named(["mph"], UnitSpeed.milesPerHour, "Miles per hour"),
        Named(["m/s"], UnitSpeed.metersPerSecond, "Metres per second"),
        Named(["knots"], UnitSpeed(symbol: "kn", converter: linear(knot)), "Knots"),
        Named(["kb"], UnitInformationStorage.kilobytes, "Kilobytes"),
        Named(["mb"], UnitInformationStorage.megabytes, "Megabytes"),
        Named(["gb"], UnitInformationStorage.gigabytes, "Gigabytes"),
        Named(["tb"], UnitInformationStorage.terabytes, "Terabytes"),
        Named(["kib"], UnitInformationStorage.kibibytes, "Kibibytes"),
        Named(["mib"], UnitInformationStorage.mebibytes, "Mebibytes"),
        Named(["gib"], UnitInformationStorage.gibibytes, "Gibibytes"),
        Named(["c", "°c", "celsius"], UnitTemperature.celsius, "Celsius"),
        Named(["f", "°f", "fahrenheit"], UnitTemperature.fahrenheit, "Fahrenheit"),
        Named(["k", "kelvin"], UnitTemperature.kelvin, "Kelvin"),
    ]

    static func answer(for text: String) -> Calculator.Answer? {
        guard
            let match = text.wholeMatch(
                of: /(-?[\d.]+) ?([a-z°\/ ]+?) (?:to|in|as|->|=) ?([a-z°\/ ]+)/),
            let value = Double(match.1),
            let source = named(match.2), let target = named(match.3),
            sameDimension(source, target)
        else { return nil }
        let converted = Measurement(value: value, unit: source.unit).converted(to: target.unit)
            .value
        guard converted.isFinite else { return nil }
        if source.unit is UnitTemperature {
            let rounded = (converted * temperatureDigits).rounded() / temperatureDigits
            return Calculator.Answer(
                kind: "Temperature",
                expression: "\(Calculator.format(value)) \(source.unit.symbol)",
                expressionDetail: source.name,
                result: "\(Calculator.format(rounded)) \(target.unit.symbol)",
                resultDetail: target.name)
        }
        return Calculator.Answer(
            kind: source.unit is UnitInformationStorage ? "Data size" : "Units",
            expression: "\(Calculator.format(value)) \(match.2)", expressionDetail: source.name,
            result: "\(Calculator.format(converted)) \(match.3)", resultDetail: target.name)
    }

    static func maths(for text: String) -> Calculator.Answer? {
        let (expression, target) = splitTarget(text)
        var rest = expression
        var sum = UnitSum()
        let token = /\s*(?:([-+*×÷\/])|(\d*\.?\d+)(?:\s*(fl oz|[a-z\/]+))?)/
        while let match = rest.prefixMatch(of: token) {
            rest = rest[match.range.upperBound...]
            guard sum.read(symbol: match.1, number: match.2, key: match.3) else { return nil }
        }
        guard rest.isEmpty, let first = sum.first, let total = sum.total() else { return nil }
        let result = target ?? first
        let value = result.unit.unit.converter.value(fromBaseUnitValue: total)
        guard sameDimension(result.unit, first.unit), value.isFinite else { return nil }
        let names = sum.names.enumerated().map { index, name in
            index == 0 ? name : name.prefix(1).lowercased() + name.dropFirst()
        }
        return Calculator.Answer(
            kind: first.unit.unit is UnitInformationStorage ? "Data size" : "Units",
            expression: sum.shown.joined(separator: " "),
            expressionDetail: names.formatted(.list(type: .and).locale(britishEnglish)),
            result: "\(Calculator.format(value)) \(result.key)", resultDetail: result.unit.name)
    }

    private static func splitTarget(_ text: String) -> (Substring, Keyed?) {
        guard let split = text.wholeMatch(of: /(.*) (?:to|in|as|->|=) ?([a-z°\/ ]+)/),
            let unit = named(split.2)
        else { return (Substring(text), nil) }
        return (split.1, (split.2, unit))
    }

    private static func named(_ key: Substring) -> Named? {
        units.first { $0.keys.contains(String(key)) }
    }

    private static func sameDimension(_ lhs: Named, _ rhs: Named) -> Bool {
        type(of: lhs.unit).baseUnit() == type(of: rhs.unit).baseUnit()
    }

    private static func linear(_ coefficient: Double) -> UnitConverterLinear {
        UnitConverterLinear(coefficient: coefficient)
    }
}
