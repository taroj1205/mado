import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetTileTests {
    private let tile = WidgetTile()

    init() {
        tile.frame = NSRect(x: 0, y: 0, width: 115, height: 78)
    }

    @Test func aSymbolSitsAtTheTopRightBesideTheValue() {
        tile.show(
            .init(
                id: "battery", value: "100%", detail: "Charged", action: "Battery Settings",
                spoken: "Battery: 100%, charged", symbol: "battery.100percent"))
        tile.layoutSubtreeIfNeeded()
        let glyph = tile.icon.alignmentRect(forFrame: tile.icon.frame)
        #expect(tile.icon.image != nil)
        #expect(abs(tile.icon.frame.width - 22) < 1)
        #expect(abs(tile.icon.frame.maxX - (tile.bounds.width - 12)) < 0.5)
        #expect(abs(glyph.midY - tile.value.frame.midY) <= 0.5)
        #expect(tile.value.frame.maxX <= tile.icon.frame.minX)
    }

    @Test func aTileWithoutASymbolDropsTheIcon() {
        tile.show(
            .init(
                id: "battery", value: "100%", detail: "Charged", action: "Battery Settings",
                spoken: "Battery: 100%, charged", symbol: "battery.100percent"))
        tile.show(
            .init(
                id: "clock", value: "9:41", detail: "Wed 30 Sep", action: "Open Clock",
                spoken: "Time: 9:41 AM, Wednesday 30 September"))
        #expect(tile.icon.image == nil)
    }
}
