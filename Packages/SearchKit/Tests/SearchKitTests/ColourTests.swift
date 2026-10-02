import Testing

@testable import SearchKit

@Suite struct ColourTests {
    @Test func theCanvasExampleFillsEveryValueOnTheCard() throws {
        let colour = try #require(Colour("#0A84FF"))
        #expect(colour.hex == "#0A84FF")
        #expect(colour.rgb == "rgb(10, 132, 255)")
        #expect(colour.hsl == "hsl(210, 100%, 52%)")
        #expect(colour.appKit == "NSColor(srgbRed: 0.039, green: 0.518, blue: 1, alpha: 1)")
        #expect(colour.closestSystemColour == "System Blue")
        #expect(colour.onWhite == "3.6 : 1")
        #expect(colour.onBlack == "5.7 : 1")
    }

    @Test(arguments: [
        "#0A84FF", "#0a84ff", "  #0A84FF ", "rgb(10, 132, 255)", "RGB(10,132,255)",
        "rgb(10 132 255)",
    ])
    func hexAndRGBNameTheSameColour(query: String) {
        #expect(Colour(query) == Colour(red: 10, green: 132, blue: 255))
    }

    @Test(arguments: [
        ("hsl(210, 100%, 52%)", Colour(red: 10, green: 133, blue: 255)),
        ("hsl(210 100% 52%)", Colour(red: 10, green: 133, blue: 255)),
        ("hsl(0, 100%, 50%)", Colour(red: 255, green: 0, blue: 0)),
        ("hsl(480, 100%, 50%)", Colour(red: 0, green: 255, blue: 0)),
        ("hsl(0, 0%, 100%)", Colour(red: 255, green: 255, blue: 255)),
        ("#fff", Colour(red: 255, green: 255, blue: 255)),
        ("#0f8", Colour(red: 0, green: 255, blue: 136)),
        ("rebeccapurple", Colour(red: 102, green: 51, blue: 153)),
        ("Tomato", Colour(red: 255, green: 99, blue: 71)),
        ("grey", Colour(red: 128, green: 128, blue: 128)),
    ])
    func hslShortHexAndCSSNamesConvertToRGB(query: String, colour: Colour) {
        #expect(Colour(query) == colour)
    }

    @Test(arguments: [
        "", "0A84FF", "#12345", "#0A84FG", "rgb(256, 0, 0)", "rgb(10, 132)", "rgb(1011225)",
        "rgba(10, 132, 255, 1)", "hsl(0, 101%, 50%)", "hsl(0, 50%, 101%)", "redd", "light blue",
        "5 ft in cm",
    ])
    func otherTextIsNotAColour(query: String) {
        #expect(Colour(query) == nil)
    }

    @Test(arguments: [
        ("#FF0000", "hsl(0, 100%, 50%)"),
        ("#FF0001", "hsl(0, 100%, 50%)"),
        ("#808080", "hsl(0, 0%, 50%)"),
        ("#000000", "hsl(0, 0%, 0%)"),
        ("#00FF88", "hsl(152, 100%, 50%)"),
        ("#663399", "hsl(270, 50%, 40%)"),
    ])
    func hslRoundsHueIntoOneTurn(hex: String, hsl: String) {
        #expect(Colour(hex)?.hsl == hsl)
    }

    @Test func hexRGBAndAppKitCopiesGiveBackTheSameColour() throws {
        for value in 0...255 {
            let colour = Colour(red: value, green: 255 - value, blue: value / 2)
            #expect(Colour(colour.hex) == colour)
            #expect(Colour(colour.rgb) == colour)
            let red = try #require(colour.appKit.firstMatch(of: /srgbRed: ([\d.]+)/)?.1)
            #expect((try #require(Double(red)) * 255).rounded() == Double(value))
        }
    }

    @Test(arguments: [
        ("#FFFFFF", "21 : 1", "1 : 1"),
        ("#000000", "1 : 1", "21 : 1"),
        ("#777777", "4.6 : 1", "4.4 : 1"),
        ("#767676", "4.6 : 1", "4.5 : 1"),
    ])
    func contrastIsCutNotRoundedSoAFailingRatioNeverReadsAsPassing(
        hex: String, onBlack: String, onWhite: String
    ) {
        #expect(Colour(hex)?.onBlack == onBlack)
        #expect(Colour(hex)?.onWhite == onWhite)
    }

    @Test(arguments: [
        ("#FF0000", "System Red"), ("orange", "System Orange"), ("#808080", "System Gray"),
        ("#FFFFFF", "White"), ("#000", "Black"), ("hsl(275, 70%, 55%)", "System Purple"),
    ])
    func theClosestSystemColourComesFromAppKit(query: String, name: String) {
        #expect(Colour(query)?.closestSystemColour == name)
    }
}
