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
        ("15% of 24*533", "1,918.8"),
        ("50% of 50% of 80", "20"),
        ("200 + 10% of 50", "205"),
        ("200 + 15% + 30%", "299"),
        ("(200+10%)*2", "440"),
        ("100 - 20% - 10%", "72"),
        ("15% + 30%", "0.45"),
        ("15% + 30% + 200", "200.45"),
        ("200 + (10%)", "200.1"),
        ("15%of240", "36"),
        ("what is 2+2", "4"),
        ("log(1000)", "3"),
        ("log10(100)+1", "3"),
        ("log2(8)*2", "6"),
        ("ln(e)", "1"),
        ("2 * pi", "6.2832"),
        ("sqrt(16)+abs(-2)", "6"),
        ("exp(0)", "1"),
        ("sin(0)", "0"),
        ("cos(0)+tan(0)", "1"),
        ("-log(100)^2", "-4"),
        ("log(sqrt(10000))", "2"),
        ("log (100) % ", "0.02"),
        ("log(8, 2)", "3"),
        ("max(10,200)", "200"),
        ("max(10, 200) - min(3, 1, 2)", "199"),
        ("round(2.567, 2)", "2.57"),
        ("round(2.5)", "3"),
        ("pow(2, 10)", "1,024"),
        ("floor(2.7) + ceil(2.1) + trunc(-1.9)", "4"),
        ("cbrt(27)", "3"),
        ("asin(1) * 2", "3.1416"),
        ("5!", "120"),
        ("0!", "1"),
        ("3! + 2", "8"),
        ("(3)!", "6"),
        ("-3!", "-6"),
        ("-1!", "-1"),
        ("pi(2)", "6.2832"),
        ("2*e(1)", "5.4366"),
        ("10 mod 3", "1"),
        ("-7 mod 3", "-1"),
        ("10 mod 3 + 1", "2"),
        ("sin(30°)", "0.5"),
        ("sin(30 degrees)", "0.5"),
        ("deg(pi)", "180"),
        ("rad(180)", "3.1416"),
        ("1e3 + 1", "1,001"),
        ("2.5e-3", "0.0025"),
        ("2e+3", "2,000"),
        ("2(3+4)", "14"),
        ("(1+2)(3+4)", "21"),
        ("3 sqrt(16)", "12"),
        ("2pi", "6.2832"),
        ("2 π", "6.2832"),
        ("π*2", "6.2832"),
        ("2 * e", "5.4366"),
        ("5 squared", "25"),
        ("(2+3) squared + 1", "26"),
        ("3 cubed", "27"),
        ("2 to the power of 8", "256"),
        ("10 plus 5", "15"),
        ("20 minus 5 times 2", "10"),
        ("100 divided by 8", "12.5"),
        ("7 multiplied by 6", "42"),
        ("15 percent of 240", "36"),
        ("square root of 144", "12"),
        ("cube root of 27", "3"),
        ("what is 7 times 8", "56"),
        ("170!", "7.2574E306"),
        ("10^15", "1E15"),
        ("10^14", "100,000,000,000,000"),
    ])
    func mathsEvaluates(query: String, result: String) {
        #expect(Calculator.answer(for: query)?.result == result)
    }

    @Test(arguments: [
        "", "42", "-42", "safari", "xcode", "c++", "2+", "*2", "2**3", "(1+2", "1+2)", "()",
        "1/0", "0/0", "1.2.3+1", "1 2+3", "2^99999", "1,2+3", "15% offset 2",
        "of 2", "2 of", "log(0)", "log(-1)", "sqrt(-4)", "log", "log()", "log(10", "log 100",
        "foo(2)", "2*pi2", "171!", "3.5!", "10 mod 0", "log(8,)",
        "max()", "max(1,", "round(1.5, 99)", "round(1, 2, 3)", "log(1, 2, 3)", "2e+", "2 3",
        "5 apples * 3", "apple + 2", "x + y", "c++", "1e999", "0 mod 0", "sqrt(2",
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

    @Test func functionsArePrettyPrinted() {
        #expect(Calculator.answer(for: "2 * LOG (100)")?.expression == "2 × log(100)")
    }

    @Test(arguments: [
        ("3 sqrt(16)", "3 × sqrt(16)"), ("2(3+4)", "2 × (3 + 4)"), ("2pi", "2 × pi"),
        ("max(1,2)", "max(1, 2)"), ("10 mod 3", "10 mod 3"), ("sin(30 deg)", "sin(30°)"),
        ("5 squared", "5 ^ 2"), ("10 plus 5", "10 + 5"),
    ])
    func newSyntaxIsPrettyPrinted(query: String, expression: String) {
        #expect(Calculator.answer(for: query)?.expression == expression)
    }

    @Test func spokenArithmeticIsSpelledOut() {
        #expect(Calculator.answer(for: "10 plus 5")?.expressionDetail == "Ten plus five")
    }

    @Test func hugeResultsAreGroupedAndNotSpelledOut() {
        let answer = Calculator.answer(for: "10^12")
        #expect(answer?.result == "1,000,000,000,000")
        #expect(answer?.resultDetail == "Result")
    }

    @Test(arguments: [
        ("15% of 240", "15% of 240", "Part of a total", "36"),
        ("what is 15% of 240", "15% of 240", "Part of a total", "36"),
        ("20% off 1,500", "20% off 1500", "Discount", "1,200"),
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
