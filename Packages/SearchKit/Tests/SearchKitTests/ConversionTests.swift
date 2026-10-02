import Testing

@testable import SearchKit

@Suite struct ConversionTests {
    @Test(arguments: [
        (
            "5 ft in cm",
            Calculator.Answer(
                kind: "Units", expression: "5 ft", expressionDetail: "Feet", result: "152.4 cm",
                resultDetail: "Centimetres")
        ),
        (
            "30 c to f",
            Calculator.Answer(
                kind: "Temperature", expression: "30 °C", expressionDetail: "Celsius",
                result: "86 °F", resultDetail: "Fahrenheit")
        ),
        (
            "1.5 gb in mb",
            Calculator.Answer(
                kind: "Data size", expression: "1.5 gb", expressionDetail: "Gigabytes",
                result: "1,500 mb", resultDetail: "Megabytes")
        ),
    ])
    func theCanvasExamplesFillTheAnswerCard(query: String, answer: Calculator.Answer) {
        #expect(Calculator.answer(for: query) == answer)
    }

    @Test(arguments: [
        ("1 mile in km", "1.6093 km"),
        ("12 inches to ft", "1 ft"),
        ("1 in in cm", "2.54 cm"),
        ("1 kg in lb", "2.2046 lb"),
        ("1 st to kg", "6.3503 kg"),
        ("1 cup in ml", "236.5882 ml"),
        ("2 fl oz to ml", "59.1471 ml"),
        ("1 gal in l", "3.7854 l"),
        ("1 gal in ml", "3,785.4118 ml"),
        ("1,000 lb in kg", "453.5924 kg"),
        ("1 knots to km/h", "1.852 km/h"),
        ("100 km/h to mph", "62.1371 mph"),
        ("10 m/s in kmh", "36 kmh"),
        ("1 gib in mib", "1,024 mib"),
        ("2,000 kb in mb", "2 mb"),
        ("-40 c to f", "-40 °F"),
        ("0 k in °c", "-273.15 °C"),
        ("98.6 fahrenheit as celsius", "37 °C"),
        ("-0.001 c to c", "0 °C"),
        ("5ft -> cm", "152.4 cm"),
        ("5 ft = cm", "152.4 cm"),
        ("  5   FT  IN  CM ", "152.4 cm"),
        ("what is 5 ft in cm", "152.4 cm"),
    ])
    func unitsConvert(query: String, result: String) {
        #expect(Calculator.answer(for: query)?.result == result)
    }

    @Test(arguments: [
        "5 ft in kg", "30 c to mb", "5 ft in parsecs", "5 parsecs in ft", "5 gb", "ft in cm",
        "5 ft in", "1.2.3 ft in cm", ". ft in cm", "5 ft into cm", "5 ft in cm cm",
        "1" + String(repeating: "0", count: 400) + " tb in kb",
    ])
    func invalidConversionsHaveNoAnswer(query: String) {
        #expect(Calculator.answer(for: query) == nil)
    }

    @Test(arguments: [
        (
            "5 ft + 5 cm",
            Calculator.Answer(
                kind: "Units", expression: "5 ft + 5 cm",
                expressionDetail: "Feet and centimetres", result: "5.164 ft",
                resultDetail: "Feet")
        ),
        (
            "5 ft 2 in to cm",
            Calculator.Answer(
                kind: "Units", expression: "5 ft 2 in", expressionDetail: "Feet and inches",
                result: "157.48 cm", resultDetail: "Centimetres")
        ),
        (
            "3 × 250 g",
            Calculator.Answer(
                kind: "Units", expression: "3 × 250 g", expressionDetail: "Grams",
                result: "750 g", resultDetail: "Grams")
        ),
        (
            "1 mi - 300 m in km",
            Calculator.Answer(
                kind: "Units", expression: "1 mi - 300 m", expressionDetail: "Miles and metres",
                result: "1.3093 km", resultDetail: "Kilometres")
        ),
        (
            "1 gb + 512 mib",
            Calculator.Answer(
                kind: "Data size", expression: "1 gb + 512 mib",
                expressionDetail: "Gigabytes and mebibytes", result: "1.5369 gb",
                resultDetail: "Gigabytes")
        ),
    ])
    func theUnitMathsExamplesFillTheAnswerCard(query: String, answer: Calculator.Answer) {
        #expect(Calculator.answer(for: query) == answer)
    }

    @Test(arguments: [
        ("10 ft - 2 ft 6 in", "7.5 ft"),
        ("250 g * 3", "750 g"),
        ("1 kg / 4 in g", "250 g"),
        ("2 × 3 ft × 2", "12 ft"),
        ("1 ft + 2 × 3 in", "1.5 ft"),
        ("5ft2in in cm", "157.48 cm"),
        ("1 cup + 2 tbsp in ml", "266.1618 ml"),
        ("2 fl oz + 1 cup in fl oz", "10 fl oz"),
        ("60 km/h + 10 mph", "76.0934 km/h"),
        ("1 ft - 12 in", "0 ft"),
        ("1 ft + 1 in + 1 cm", "1.1161 ft"),
        ("5 feet + 2 inches", "5.1667 feet"),
        ("1,000 g + 1 kg", "2,000 g"),
        ("what is 5 ft + 5 cm", "5.164 ft"),
    ])
    func unitMathsEvaluates(query: String, result: String) {
        #expect(Calculator.answer(for: query)?.result == result)
    }

    @Test func unitNamesAreListedOnceInTheOrderTyped() {
        #expect(
            Calculator.answer(for: "1 ft + 1 in + 1 cm + 2 feet")?.expressionDetail
                == "Feet, inches and centimetres")
        #expect(
            Calculator.answer(for: "1 cup + 1 gal")?.expressionDetail
                == "Cups (US) and gallons (US)")
    }

    @Test(arguments: [
        "5 ft + 2 kg", "5 ft + 5 cm in kg", "30 c + 5 c", "30 c + 5 c to f", "2 ft × 3 ft",
        "10 ft ÷ 2 ft", "6 ÷ 2 ft", "5 ft + 3", "3 + 5 ft", "5 ft 2", "5 2 ft",
        "5 ft +", "+ 5 ft", "5 ft + + 2 ft", "5 ft + 2 parsecs", "5 ft + 2 ft in parsecs",
        "5 ft ÷ 0", "1.2.3 ft + 1 ft", "-5 ft + 2 ft", "5 ft + (2 ft)",
        "1" + String(repeating: "0", count: 400) + " tb - 1 tb",
    ])
    func unsupportedUnitMathsHasNoAnswer(query: String) {
        #expect(Calculator.answer(for: query) == nil)
    }
}
