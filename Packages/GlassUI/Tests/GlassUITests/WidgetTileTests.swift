import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetTileTests {
    private let tile = WidgetTile(floating: false)

    init() {
        tile.frame = NSRect(x: 0, y: 0, width: 115, height: 78)
    }

    @Test func aSymbolSitsAtTheTopRightBesideTheValue() {
        tile.show(
            .init(
                id: "battery", name: "Battery", value: "100%", detail: "Charged",
                action: "Battery Settings",
                spoken: "Battery: 100%, charged", symbol: "battery.100percent"))
        tile.layoutSubtreeIfNeeded()
        let glyph = tile.icon.alignmentRect(forFrame: tile.icon.frame)
        let frame = tile.convert(tile.value.bounds, from: tile.value)
        let value = tile.value.alignmentRect(forFrame: frame)
        #expect(tile.icon.image != nil)
        #expect(glyph.width > 0)
        #expect(abs(glyph.maxX - (tile.bounds.width - 12)) <= 1)
        #expect(abs(glyph.midY - value.midY) <= 1)
        #expect(value.maxX + 4 <= glyph.minX + 1)
    }

    @Test func aTileWithoutASymbolDropsTheIcon() {
        tile.show(
            .init(
                id: "battery", name: "Battery", value: "100%", detail: "Charged",
                action: "Battery Settings",
                spoken: "Battery: 100%, charged", symbol: "battery.100percent"))
        tile.show(
            .init(
                id: "clock", name: "Clock", value: "9:41", detail: "Wed 30 Sep",
                action: "Open Clock",
                spoken: "Time: 9:41 AM, Wednesday 30 September"))
        #expect(tile.icon.image == nil)
    }
}
