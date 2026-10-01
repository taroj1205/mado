import Testing

@testable import SearchKit

@Suite struct CalculatorTests {
    @Test(arguments: [
        ("12*(3+4)", "84"),
        ("2+3*4", "14"),
        ("(2+3)*4", "20"),
        ("10-4-3", "3"),
        ("100/8/5", "2.5"),
        ("2^3^2", "512"),
        ("-2^2", "-4"),
        ("2^-1", "0.5"),
        ("(-2)^2", "4"),
        ("-(3+4)", "-7"),
        ("3x4", "12"),
        ("6 × 7 ÷ 2", "21"),
        ("50%", "0.5"),
        ("200*15%", "30"),
        ("1,000,000/4", "250,000"),
        ("1/3", "0.333333"),
        ("10/3", "3.3333"),
        (" ( 1 + 2 ) * 3 ", "9"),
        ("-1*0", "0"),
        (".5+.25", "0.75"),
    ])
    func mathsEvaluates(query: String, result: String) {
        #expect(Calculator.answer(for: query)?.result == result)
    }

    @Test(arguments: [
        "", "42", "-42", "safari", "xcode", "c++", "2+", "*2", "2**3", "(1+2", "1+2)", "()",
        "1/0", "0/0", "1.2.3+1", "1 2+3", "2^99999", "5 ft in cm", "1,2+3",
    ])
    func invalidInputHasNoAnswer(query: String) {
        #expect(Calculator.answer(for: query) == nil)
    }

    @Test(arguments: ["(", "-", "2^"])
    func deepNestingIsRejectedWithoutCrashing(prefix: String) {
        let deep = String(repeating: prefix, count: 100_000) + "1+1"
        #expect(Calculator.answer(for: deep) == nil)
    }

    @Test func shallowNestingStillWorks() {
        let nested =
            String(repeating: "(", count: 10) + "1" + String(repeating: ")", count: 10) + "+1"
        #expect(Calculator.answer(for: nested)?.result == "2")
    }

    @Test func theCardSpellsOutASimpleSum() {
        #expect(
            Calculator.answer(for: "54 * 1.15")
                == .init(
                    kind: "Calculator", expression: "54 × 1.15",
                    expressionDetail: "Fifty-four times one point one five", result: "62.1",
                    resultDetail: "Sixty-two point one"))
    }

    @Test func longerExpressionsArePrettyPrinted() {
        let answer = Calculator.answer(for: "12*(3+4)-2^2/-1")
        #expect(answer?.expression == "12 × (3 + 4) - 2 ^ 2 ÷ -1")
        #expect(answer?.expressionDetail == "Expression")
        #expect(answer?.result == "88")
    }

    @Test func hugeResultsAreGroupedAndNotSpelledOut() {
        let answer = Calculator.answer(for: "10^12")
        #expect(answer?.result == "1,000,000,000,000")
        #expect(answer?.resultDetail == "Result")
    }

    @Test(arguments: [
        ("15% of 240", "15% of 240", "Part of a total", "36"),
        ("what is 15% of 240", "15% of 240", "Part of a total", "36"),
        ("20% off 1,500", "20% off 1,500", "Discount", "1,200"),
        ("200 + 10%", "200 + 10%", "Increase", "220"),
        ("80-25%", "80 - 25%", "Decrease", "60"),
    ])
    func percentagesHaveTheirOwnCard(
        query: String, expression: String, detail: String, result: String
    ) {
        let answer = Calculator.answer(for: query)
        #expect(answer?.kind == "Percentage")
        #expect(answer?.expression == expression)
        #expect(answer?.expressionDetail == detail)
        #expect(answer?.result == result)
    }
}
