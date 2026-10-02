import Foundation

enum Conversion {
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
            let source = units.first(where: { $0.keys.contains(String(match.2)) }),
            let target = units.first(where: { $0.keys.contains(String(match.3)) }),
            type(of: source.unit).baseUnit() == type(of: target.unit).baseUnit()
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

    private static func linear(_ coefficient: Double) -> UnitConverterLinear {
        UnitConverterLinear(coefficient: coefficient)
    }
}
