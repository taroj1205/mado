import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct ActionRowTests {
    @Test func selectedRowNestsInThePanelCornersWithALitTopEdge() throws {
        let row = ActionRow(title: "A", keys: [])
        row.frame = NSRect(x: 0, y: 0, width: 200, height: 32)
        #expect(row.cornerRadius == 12)
        let image = try #require(row.bitmapImageRepForCachingDisplay(in: row.bounds))
        row.cacheDisplay(in: row.bounds, to: image)
        #expect(image.colorAt(x: image.pixelsWide / 2, y: 0)?.alphaComponent == 0)
        row.isSelected = true
        row.cacheDisplay(in: row.bounds, to: image)
        let middle = image.pixelsWide / 2
        let top = try #require(image.colorAt(x: middle, y: 0)?.usingColorSpace(.sRGB))
        let body = try #require(
            image.colorAt(x: middle, y: image.pixelsHigh / 2)?.usingColorSpace(.sRGB))
        #expect(top.redComponent > body.redComponent)
    }

    @Test func aNoteIsGreyStaticTextThatCannotBePressed() {
        let note = ActionRow.note("No matching actions")
        #expect(note.label.textColor == .secondaryLabelColor)
        #expect(note.keycaps.isEmpty)
        #expect(note.accessibilityRole() == .staticText)
        #expect(!note.accessibilityPerformPress())
    }
}
