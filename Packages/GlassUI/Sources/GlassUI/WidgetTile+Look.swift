import AppKit

extension WidgetTile {
    typealias Look = (fill: NSColor, edge: NSColor)

    static let fillAlpha = (dark: 0.055, light: 0.55)
    static let edgeAlpha = (dark: 0.07, light: 0.06)
    static let selectedFillAlpha = (dark: 0.13, light: 0.065)
    static let selectedEdgeAlpha = (dark: 0.26, light: 0.16)
    static let editFillAlpha = (dark: 0.07, light: 0.55)
    static let editEdgeAlpha = (dark: 0.28, light: 0.2)
    static let fill = tone(.white, .white, fillAlpha)
    static let edge = tone(.white, .black, edgeAlpha)
    static let selectedFill = tone(.white, .black, selectedFillAlpha)
    static let selectedEdge = tone(.white, .black, selectedEdgeAlpha)
    static let editFill = tone(.white, .white, editFillAlpha)
    static let editEdge = tone(.white, .black, editEdgeAlpha)
    static let floatingSelectedAlpha = (dark: 0.34, light: 0.80)
    static let floatingSelectedTint = (red: 0.55, green: 0.55, blue: 0.63)
    static let floatingSelectedFill = tone(
        NSColor(
            srgbRed: floatingSelectedTint.red, green: floatingSelectedTint.green,
            blue: floatingSelectedTint.blue, alpha: 1),
        .white, floatingSelectedAlpha)
    static let inlineLooks: (resting: Look, picked: Look) = (
        (fill, edge), (selectedFill, selectedEdge)
    )
    static let floatingLooks: (resting: Look, picked: Look) = (
        (.clear, .clear), (floatingSelectedFill, selectedEdge)
    )

    static func tone(
        _ dark: NSColor, _ light: NSColor, _ alpha: (dark: Double, light: Double)
    ) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? dark.withAlphaComponent(alpha.dark) : light.withAlphaComponent(alpha.light)
        }
    }
}
