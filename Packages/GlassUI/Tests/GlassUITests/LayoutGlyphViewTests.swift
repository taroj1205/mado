import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct LayoutGlyphViewTests {
    @Test func keepsItsSizeBesideAViewThatHugsHarder() {
        let glyph = LayoutGlyphView(area: CGRect(x: 0, y: 0, width: 1, height: 1))
        let label = NSTextField(labelWithString: "Center Third")
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        let row = NSStackView(views: [glyph, label])
        row.distribution = .fill
        row.frame = NSRect(x: 0, y: 0, width: 300, height: 40)
        row.layoutSubtreeIfNeeded()
        #expect(glyph.frame.size == NSSize(width: 30, height: 20))
    }
}
