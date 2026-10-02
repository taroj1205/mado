import Foundation

enum Conversion {
    private typealias Keyed = (key: Substring, unit: Named)

    private struct Named {
        let keys: [String]
        let unit: Dimension
        let name: String
        let toMetric: String?
        let toUS: String?

        init(
            _ keys: [String], _ unit: Dimension, _ name: String, toMetric: String? = nil,
            toUS: String? = nil
        ) {
            self.keys = keys
            self.unit = unit
            self.name = name
            self.toMetric = toMetric
            self.toUS = toUS
        }

        func counterpart(in system: AnswerSettings.UnitSystem) -> String? {
            system == .metric ? toMetric ?? toUS : toUS ?? toMetric
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
        Named(["mm"], UnitLength.millimeters, "Millimetres", toUS: "in"),
        Named(["cm"], UnitLength.centimeters, "Centimetres", toUS: "in"),
        Named(["m"], UnitLength.meters, "Metres", toUS: "ft"),
        Named(["km"], UnitLength.kilometers, "Kilometres", toUS: "mi"),
        Named(["in", "inch", "inches"], UnitLength.inches, "Inches", toMetric: "cm"),
        Named(["ft", "foot", "feet"], UnitLength.feet, "Feet", toMetric: "m"),
        Named(["yd"], UnitLength.yards, "Yards", toMetric: "m"),
        Named(["mi", "mile", "miles"], UnitLength.miles, "Miles", toMetric: "km"),
        Named(["g"], UnitMass.grams, "Grams", toUS: "oz"),
        Named(["kg"], UnitMass.kilograms, "Kilograms", toUS: "lb"),
        Named(
            ["lb", "lbs"], UnitMass(symbol: "lb", converter: linear(pound)), "Pounds",
            toMetric: "kg"),
        Named(["oz"], UnitMass(symbol: "oz", converter: linear(ounce)), "Ounces", toMetric: "g"),
        Named(["st"], UnitMass(symbol: "st", converter: linear(stone)), "Stone", toMetric: "kg"),
        Named(["ml"], UnitVolume.milliliters, "Millilitres", toUS: "fl oz"),
        Named(["l", "litre", "litres"], UnitVolume.liters, "Litres", toUS: "gal"),
        Named(
            ["cup", "cups"], UnitVolume(symbol: "cup", converter: linear(cup)), "Cups (US)",
            toMetric: "ml"),
        Named(
            ["tbsp"], UnitVolume(symbol: "tbsp", converter: linear(tablespoon)), "Tablespoons",
            toMetric: "ml"),
        Named(
            ["tsp"], UnitVolume(symbol: "tsp", converter: linear(teaspoon)), "Teaspoons",
            toMetric: "ml"),
        Named(
            ["gal"], UnitVolume(symbol: "gal", converter: linear(gallon)), "Gallons (US)",
            toMetric: "l"),
        Named(
            ["fl oz"], UnitVolume(symbol: "fl oz", converter: linear(fluidOunce)), "Fluid ounces",
            toMetric: "ml"),
        Named(
            ["kmh", "km/h"], UnitSpeed(symbol: "km/h", converter: linear(kilometrePerHour)),
            "Kilometres per hour", toUS: "mph"),
        Named(["mph"], UnitSpeed.milesPerHour, "Miles per hour", toMetric: "km/h"),
        Named(["m/s"], UnitSpeed.metersPerSecond, "Metres per second", toUS: "mph"),
        Named(
            ["knots"], UnitSpeed(symbol: "kn", converter: linear(knot)), "Knots", toMetric: "km/h",
            toUS: "mph"),
        Named(["kb"], UnitInformationStorage.kilobytes, "Kilobytes"),
        Named(["mb"], UnitInformationStorage.megabytes, "Megabytes"),
        Named(["gb"], UnitInformationStorage.gigabytes, "Gigabytes"),
        Named(["tb"], UnitInformationStorage.terabytes, "Terabytes"),
        Named(["kib"], UnitInformationStorage.kibibytes, "Kibibytes"),
        Named(["mib"], UnitInformationStorage.mebibytes, "Mebibytes"),
        Named(["gib"], UnitInformationStorage.gibibytes, "Gibibytes"),
        Named(["c", "°c", "celsius"], UnitTemperature.celsius, "Celsius", toUS: "f"),
        Named(["f", "°f", "fahrenheit"], UnitTemperature.fahrenheit, "Fahrenheit", toMetric: "c"),
        Named(["k", "kelvin"], UnitTemperature.kelvin, "Kelvin", toMetric: "c", toUS: "f"),
    ]

    static func answer(for text: String) -> Calculator.Answer? {
        guard
            let match = text.wholeMatch(
                of: /(-?[\d.]+) ?([a-z°\/ ]+?) (?:to|in|as|->|=) ?([a-z°\/ ]+)/),
            let value = Double(match.1),
            let source = named(match.2), let target = named(match.3)
        else { return nil }
        return answer(value, from: (match.2, source), to: (match.3, target))
    }

    static func answer(
        for text: String, preferring settings: AnswerSettings, in region: Locale
    ) -> Calculator.Answer? {
        guard let match = text.wholeMatch(of: /(-?[\d.]+) ?([a-z°\/ ]+)/),
            let value = Double(match.1), let source = named(match.2)
        else { return nil }
        let system =
            source.unit is UnitTemperature
            ? settings.temperature(in: region) : settings.measures(in: region)
        guard let key = source.counterpart(in: system), let target = named(Substring(key)) else {
            return nil
        }
        return answer(value, from: (match.2, source), to: (Substring(key), target))
    }

    private static func answer(
        _ value: Double, from source: Keyed, to target: Keyed
    ) -> Calculator.Answer? {
        guard sameDimension(source.unit, target.unit) else { return nil }
        let converted = Measurement(value: value, unit: source.unit.unit)
            .converted(to: target.unit.unit).value
        guard converted.isFinite else { return nil }
        if source.unit.unit is UnitTemperature {
            let rounded = (converted * temperatureDigits).rounded() / temperatureDigits
            return Calculator.Answer(
                kind: "Temperature",
                expression: "\(Calculator.format(value)) \(source.unit.unit.symbol)",
                expressionDetail: source.unit.name,
                result: "\(Calculator.format(rounded)) \(target.unit.unit.symbol)",
                resultDetail: target.unit.name)
        }
        return Calculator.Answer(
            kind: source.unit.unit is UnitInformationStorage ? "Data size" : "Units",
            expression: "\(Calculator.format(value)) \(source.key)",
            expressionDetail: source.unit.name,
            result: "\(Calculator.format(converted)) \(target.key)", resultDetail: target.unit.name)
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
