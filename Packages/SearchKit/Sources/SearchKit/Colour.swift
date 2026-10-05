import AppKit

public struct Colour: Sendable, Equatable {
    private static let names: [String: String] = [
        "aliceblue": "f0f8ff", "antiquewhite": "faebd7", "aqua": "00ffff", "aquamarine": "7fffd4",
        "azure": "f0ffff", "beige": "f5f5dc", "bisque": "ffe4c4", "black": "000000",
        "blanchedalmond": "ffebcd", "blue": "0000ff", "blueviolet": "8a2be2", "brown": "a52a2a",
        "burlywood": "deb887", "cadetblue": "5f9ea0", "chartreuse": "7fff00",
        "chocolate": "d2691e", "coral": "ff7f50", "cornflowerblue": "6495ed", "cornsilk": "fff8dc",
        "crimson": "dc143c", "cyan": "00ffff", "darkblue": "00008b", "darkcyan": "008b8b",
        "darkgoldenrod": "b8860b", "darkgray": "a9a9a9", "darkgreen": "006400",
        "darkgrey": "a9a9a9", "darkkhaki": "bdb76b", "darkmagenta": "8b008b",
        "darkolivegreen": "556b2f", "darkorange": "ff8c00", "darkorchid": "9932cc",
        "darkred": "8b0000", "darksalmon": "e9967a", "darkseagreen": "8fbc8f",
        "darkslateblue": "483d8b", "darkslategray": "2f4f4f", "darkslategrey": "2f4f4f",
        "darkturquoise": "00ced1", "darkviolet": "9400d3", "deeppink": "ff1493",
        "deepskyblue": "00bfff", "dimgray": "696969", "dimgrey": "696969", "dodgerblue": "1e90ff",
        "firebrick": "b22222", "floralwhite": "fffaf0", "forestgreen": "228b22",
        "fuchsia": "ff00ff", "gainsboro": "dcdcdc", "ghostwhite": "f8f8ff", "gold": "ffd700",
        "goldenrod": "daa520", "gray": "808080", "green": "008000", "greenyellow": "adff2f",
        "grey": "808080", "honeydew": "f0fff0", "hotpink": "ff69b4", "indianred": "cd5c5c",
        "indigo": "4b0082", "ivory": "fffff0", "khaki": "f0e68c", "lavender": "e6e6fa",
        "lavenderblush": "fff0f5", "lawngreen": "7cfc00", "lemonchiffon": "fffacd",
        "lightblue": "add8e6", "lightcoral": "f08080", "lightcyan": "e0ffff",
        "lightgoldenrodyellow": "fafad2", "lightgray": "d3d3d3", "lightgreen": "90ee90",
        "lightgrey": "d3d3d3", "lightpink": "ffb6c1", "lightsalmon": "ffa07a",
        "lightseagreen": "20b2aa", "lightskyblue": "87cefa", "lightslategray": "778899",
        "lightslategrey": "778899", "lightsteelblue": "b0c4de", "lightyellow": "ffffe0",
        "lime": "00ff00", "limegreen": "32cd32", "linen": "faf0e6", "magenta": "ff00ff",
        "maroon": "800000", "mediumaquamarine": "66cdaa", "mediumblue": "0000cd",
        "mediumorchid": "ba55d3", "mediumpurple": "9370db", "mediumseagreen": "3cb371",
        "mediumslateblue": "7b68ee", "mediumspringgreen": "00fa9a", "mediumturquoise": "48d1cc",
        "mediumvioletred": "c71585", "midnightblue": "191970", "mintcream": "f5fffa",
        "mistyrose": "ffe4e1", "moccasin": "ffe4b5", "navajowhite": "ffdead", "navy": "000080",
        "oldlace": "fdf5e6", "olive": "808000", "olivedrab": "6b8e23", "orange": "ffa500",
        "orangered": "ff4500", "orchid": "da70d6", "palegoldenrod": "eee8aa",
        "palegreen": "98fb98", "paleturquoise": "afeeee", "palevioletred": "db7093",
        "papayawhip": "ffefd5", "peachpuff": "ffdab9", "peru": "cd853f", "pink": "ffc0cb",
        "plum": "dda0dd", "powderblue": "b0e0e6", "purple": "800080", "rebeccapurple": "663399",
        "red": "ff0000", "rosybrown": "bc8f8f", "royalblue": "4169e1", "saddlebrown": "8b4513",
        "salmon": "fa8072", "sandybrown": "f4a460", "seagreen": "2e8b57", "seashell": "fff5ee",
        "sienna": "a0522d", "silver": "c0c0c0", "skyblue": "87ceeb", "slateblue": "6a5acd",
        "slategray": "708090", "slategrey": "708090", "snow": "fffafa", "springgreen": "00ff7f",
        "steelblue": "4682b4", "tan": "d2b48c", "teal": "008080", "thistle": "d8bfd8",
        "tomato": "ff6347", "turquoise": "40e0d0", "violet": "ee82ee", "wheat": "f5deb3",
        "white": "ffffff", "whitesmoke": "f5f5f5", "yellow": "ffff00", "yellowgreen": "9acd32",
    ]

    private static let systemColours: [(name: String, colour: NSColor)] = [
        ("System Red", .systemRed), ("System Orange", .systemOrange),
        ("System Yellow", .systemYellow), ("System Green", .systemGreen),
        ("System Mint", .systemMint), ("System Teal", .systemTeal), ("System Cyan", .systemCyan),
        ("System Blue", .systemBlue), ("System Indigo", .systemIndigo),
        ("System Purple", .systemPurple), ("System Pink", .systemPink),
        ("System Brown", .systemBrown), ("System Gray", .systemGray), ("White", .white),
        ("Black", .black),
    ]

    private static let system: [(name: String, lab: SIMD3<Double>)] = {
        let appearances = [NSAppearance.Name.aqua, .darkAqua].compactMap(NSAppearance.init)
        return systemColours.flatMap { name, colour in
            appearances.compactMap { appearance in
                var lab: SIMD3<Double>?
                appearance.performAsCurrentDrawingAppearance { lab = Self.lab(colour.cgColor) }
                return lab.map { (name, $0) }
            }
        }
    }()

    private static let locale = Locale(identifier: "en_US")
    private static let byte = 255.0
    private static let hexRadix = 16
    private static let shortHexLength = 3
    private static let hexLength = 6
    private static let redShift = 16
    private static let greenShift = 8
    private static let half = 0.5
    private static let percent = 100.0
    private static let fullTurn = 360
    private static let hueSector = 60.0
    private static let hslSector = 30.0
    private static let hslSectors = 12.0
    private static let hslGreen = 8.0
    private static let hslBlue = 4.0
    private static let hslRise = 3.0
    private static let hslFall = 9.0
    private static let greenSector = 2.0
    private static let blueSector = 4.0
    private static let redWrap = 6.0
    private static let linearLimit = 0.04045
    private static let linearSlope = 12.92
    private static let gammaOffset = 0.055
    private static let gammaScale = 1.055
    private static let gamma = 2.4
    private static let redWeight = 0.2126
    private static let greenWeight = 0.7152
    private static let blueWeight = 0.0722
    private static let flare = 0.05
    private static let ratioDigits = 1
    private static let ratioScale = 10.0
    private static let ratioTolerance = 1e-9
    private static let componentDigits = 3
    private static let componentNames = ["srgbRed", "green", "blue"]

    public let red: Int
    public let green: Int
    public let blue: Int

    public var hex: String {
        let digits = String(
            red << Self.redShift | green << Self.greenShift | blue, radix: Self.hexRadix)
        return "#" + String(repeating: "0", count: Self.hexLength - digits.count)
            + digits.uppercased()
    }

    public var rgb: String {
        "rgb(\(red), \(green), \(blue))"
    }

    public var hsl: String {
        let channels = components
        let high = channels.max()
        let low = channels.min()
        let delta = high - low
        let lightness = (high + low) * Self.half
        guard delta > 0 else { return "hsl(0, 0%, \(Self.percentage(lightness))%)" }
        let saturation = (high - lightness) / min(lightness, 1 - lightness)
        let sector =
            switch high {
            case channels.x:
                (channels.y - channels.z) / delta + (channels.y < channels.z ? Self.redWrap : 0)

            case channels.y:
                (channels.z - channels.x) / delta + Self.greenSector

            default:
                (channels.x - channels.y) / delta + Self.blueSector
            }
        let hue = Int((sector * Self.hueSector).rounded()) % Self.fullTurn
        return "hsl(\(hue), \(Self.percentage(saturation))%, \(Self.percentage(lightness))%)"
    }

    public var appKit: String {
        let parts = zip(Self.componentNames, [red, green, blue]).map { name, value in
            "\(name): \(Self.number(Double(value) / Self.byte, digits: Self.componentDigits))"
        }
        return "NSColor(\(parts.joined(separator: ", ")), alpha: 1)"
    }

    public var closestSystemColour: String {
        guard let lab = Self.lab(cgColor) else { return "" }
        let closest = Self.system.min { first, second in
            Self.distance(first.lab, lab) < Self.distance(second.lab, lab)
        }
        return closest?.name ?? ""
    }

    public var onWhite: String {
        Self.ratio((1 + Self.flare) / (luminance + Self.flare))
    }

    public var onBlack: String {
        Self.ratio((luminance + Self.flare) / Self.flare)
    }

    private var components: SIMD3<Double> {
        SIMD3(Double(red), Double(green), Double(blue)) / Self.byte
    }

    private var cgColor: CGColor {
        CGColor(srgbRed: components.x, green: components.y, blue: components.z, alpha: 1)
    }

    private var luminance: Double {
        let channels = components
        let linear = SIMD3(
            Self.linear(channels.x), Self.linear(channels.y), Self.linear(channels.z))
        return (linear * SIMD3(Self.redWeight, Self.greenWeight, Self.blueWeight)).sum()
    }

    public init?(_ query: String) {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard
            let colour = Self.hex(text) ?? Self.rgb(text) ?? Self.hsl(text)
                ?? Self.names[text].flatMap({ Self.hex("#" + $0) })
        else { return nil }
        self = colour
    }

    public init(red: Int, green: Int, blue: Int) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    private static func hex(_ text: String) -> Self? {
        guard let match = text.wholeMatch(of: /#([0-9a-f]{3}|[0-9a-f]{6})/) else { return nil }
        let digits =
            match.1.count == shortHexLength
            ? match.1.map { "\($0)\($0)" }.joined() : String(match.1)
        guard let value = Int(digits, radix: hexRadix) else { return nil }
        let mask = Int(byte)
        return Self(
            red: value >> redShift & mask, green: value >> greenShift & mask, blue: value & mask)
    }

    private static func rgb(_ text: String) -> Self? {
        guard
            let match = text.wholeMatch(
                of: /rgb\(\s*(\d{1,3})(?:\s*,\s*|\s+)(\d{1,3})(?:\s*,\s*|\s+)(\d{1,3})\s*\)/),
            let redValue = Int(match.1), let greenValue = Int(match.2),
            let blueValue = Int(match.3),
            [redValue, greenValue, blueValue].allSatisfy({ $0 <= Int(byte) })
        else { return nil }
        return Self(red: redValue, green: greenValue, blue: blueValue)
    }

    private static func hsl(_ text: String) -> Self? {
        guard
            let match = text.wholeMatch(
                of: /hsl\(\s*(\d{1,3})(?:\s*,\s*|\s+)(\d{1,3})%?(?:\s*,\s*|\s+)(\d{1,3})%?\s*\)/),
            let hue = Double(match.1), let saturation = Double(match.2),
            let lightness = Double(match.3), saturation <= percent, lightness <= percent
        else { return nil }
        let level = lightness / percent
        let chroma = saturation / percent * min(level, 1 - level)
        func channel(_ offset: Double) -> Int {
            let turn = (offset + hue / hslSector).truncatingRemainder(dividingBy: hslSectors)
            let ramp = max(-1, min(turn - hslRise, hslFall - turn, 1))
            return Int(((level - chroma * ramp) * byte).rounded())
        }
        return Self(red: channel(0), green: channel(hslGreen), blue: channel(hslBlue))
    }

    private static func linear(_ value: Double) -> Double {
        value <= linearLimit ? value / linearSlope : pow((value + gammaOffset) / gammaScale, gamma)
    }

    private static func lab(_ colour: CGColor) -> SIMD3<Double>? {
        guard let space = CGColorSpace(name: CGColorSpace.genericLab),
            let values = colour.converted(
                to: space, intent: .relativeColorimetric, options: nil)?.components
        else { return nil }
        let lab = values.prefix(SIMD3<Double>.scalarCount).map(Double.init)
        return lab.count == SIMD3<Double>.scalarCount ? SIMD3(lab) : nil
    }

    private static func distance(_ first: SIMD3<Double>, _ second: SIMD3<Double>) -> Double {
        ((first - second) * (first - second)).sum()
    }

    private static func percentage(_ fraction: Double) -> Int {
        Int((fraction * percent).rounded())
    }

    private static func ratio(_ value: Double) -> String {
        let cut = (value * ratioScale + ratioTolerance).rounded(.down) / ratioScale
        return "\(number(cut, digits: ratioDigits)) : 1"
    }

    private static func number(_ value: Double, digits: Int) -> String {
        value.formatted(.number.locale(locale).precision(.fractionLength(0...digits)))
    }
}
