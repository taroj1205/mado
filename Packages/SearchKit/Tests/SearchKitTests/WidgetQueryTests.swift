import Testing

@testable import SearchKit

@Suite struct WidgetQueryTests {
    @Test(arguments: [
        ("weather", WidgetQuery.Kind.weather), ("wea", .weather), (" Weath ", .weather),
        ("forecast", .weather), ("for", .weather), ("battery", .battery), ("bat", .battery),
        ("cpu", .system), ("mem", .system), ("memory", .system), ("ram", .system),
        ("proc", .system), ("calendar", .calendar), ("CAL", .calendar), ("calend", .calendar),
    ])
    func aKeywordOrItsStartOpensItsWidget(query: String, kind: WidgetQuery.Kind) {
        #expect(WidgetQuery.kinds(for: query) == [kind])
    }

    @Test(arguments: ["", "w", "we", "ca", "cp", "ra", " we ", "weathers", "calc", "calculator"])
    func tooShortOrUnrelatedQueriesOpenNothing(query: String) {
        #expect(WidgetQuery.kinds(for: query).isEmpty)
    }

    @Test(arguments: ["weather in tokyo", "battery life", "cpu usage", "system", "agenda", "today"])
    func aLongerPhraseOpensNothing(query: String) {
        #expect(WidgetQuery.kinds(for: query).isEmpty)
    }
}
