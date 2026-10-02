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
        "5 ft in kg", "30 c to mb", "5 ft in parsecs", "5 parsecs in ft", "5 ft", "ft in cm",
        "5 ft in", "1.2.3 ft in cm", ". ft in cm", "5 ft into cm", "5 ft in cm cm",
        "1" + String(repeating: "0", count: 400) + " tb in kb",
    ])
    func invalidConversionsHaveNoAnswer(query: String) {
        #expect(Calculator.answer(for: query) == nil)
    }
}
