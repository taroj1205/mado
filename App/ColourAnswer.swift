import AppCore
import AppKit
import GlassUI
import SearchKit

@MainActor
enum ColourAnswer {
    static let context = "Colour"
    static let symbol = "paintpalette.fill"
    static let shortcutKeys = [rgbKeys, hslKeys, appKitKeys]
    private static let rgbKeys = ["⌘", "1"]
    private static let hslKeys = ["⌘", "2"]
    private static let appKitKeys = ["⌘", "3"]
    private static let prefix = "colour."
    private static let byte: CGFloat = 255

    static func owns(_ id: String) -> Bool {
        id.hasPrefix(prefix)
    }

    static func section(for query: String) -> ResultList.Section? {
        guard let colour = Colour(query) else { return nil }
        let swatch = NSColor(
            srgbRed: CGFloat(colour.red) / byte, green: CGFloat(colour.green) / byte,
            blue: CGFloat(colour.blue) / byte, alpha: 1)
        return ResultList.Section(
            title: "Copy as", items: copies(of: colour),
            colour: ResultList.ColourCard(
                swatch: swatch, hex: colour.hex, rgb: colour.rgb, hsl: colour.hsl,
                closest: colour.closestSystemColour, onWhite: colour.onWhite,
                onBlack: colour.onBlack))
    }

    static func actions(for id: String, query: String) -> [CommandAction] {
        guard let colour = Colour(query),
            let item = copies(of: colour).first(where: { $0.id == id })
        else { return [] }
        return [
            CommandAction(id: "copy", title: item.action) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.subtitle, forType: .string)
            }
        ]
    }

    private static func copies(of colour: Colour) -> [ResultList.Item] {
        [
            ("hex", "Copy HEX", colour.hex, "number", ["↵"]),
            ("rgb", "Copy RGB", colour.rgb, "doc.on.doc", rgbKeys),
            ("hsl", "Copy HSL", colour.hsl, "doc.on.doc", hslKeys),
            (
                "appkit", "Copy for AppKit", colour.appKit,
                "chevron.left.forwardslash.chevron.right", appKitKeys
            ),
        ].map { id, title, value, symbol, keys in
            ResultList.Item(
                id: prefix + id, title: title, subtitle: value, kind: "", symbol: symbol,
                action: title, shortcut: keys)
        }
    }
}
