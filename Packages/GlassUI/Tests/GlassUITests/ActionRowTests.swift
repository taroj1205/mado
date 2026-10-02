import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct ActionRowTests {
    @Test func selectedRowNestsInThePanelCornersWithALitTopEdge() throws {
        let row = ActionRow(title: "A", keys: [], icon: nil, isDestructive: false)
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

    @Test func aDestructiveRowIsRedUntilSelected() {
        let row = ActionRow(
            title: "Quit Application", keys: ["⌘", "Q"], icon: nil, isDestructive: true)
        #expect(row.label.textColor == .systemRed)
        row.isSelected = true
        #expect(row.label.textColor == .white)
        row.isSelected = false
        #expect(row.label.textColor == .systemRed)
    }

    @Test func anIconSitsBeforeTheTitle() throws {
        let row = ActionRow(
            title: "Preview", keys: [], icon: NSImage(size: NSSize(width: 32, height: 32)),
            isDestructive: false)
        row.frame = NSRect(x: 0, y: 0, width: 300, height: 32)
        row.layoutSubtreeIfNeeded()
        let icon = try #require(row.contentView?.subviews.first { $0 is NSImageView })
        #expect(icon.frame == NSRect(x: 10, y: 8, width: 16, height: 16))
        #expect(row.label.alignmentRect(forFrame: row.label.frame).minX == icon.frame.maxX + 8)
    }

    @Test func aNoteIsGreyStaticTextThatCannotBePressed() {
        let note = ActionRow.note("No matching actions")
        #expect(note.label.textColor == .secondaryLabelColor)
        #expect(note.keycaps.isEmpty)
        #expect(note.accessibilityRole() == .staticText)
        #expect(!note.accessibilityPerformPress())
    }
}
