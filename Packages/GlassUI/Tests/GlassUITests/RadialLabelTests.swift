import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct RadialLabelTests {
    private static let screen = NSRect(x: 0, y: 0, width: 1_440, height: 900)
    private let label = RadialLabel()

    @Test func sitsCentredSixPointsBelowTheRing() {
        let ring = NSRect(x: 640, y: 400, width: 120, height: 120)
        #expect(
            RadialLabel.frame(width: 100, below: ring, on: Self.screen)
                == NSRect(x: 650, y: 368, width: 100, height: 26))
    }

    @Test func movesAboveTheRingWhenTheScreenEndsBelowIt() {
        let ring = NSRect(x: 640, y: 10, width: 120, height: 120)
        #expect(RadialLabel.frame(width: 100, below: ring, on: Self.screen).minY == 136)
    }

    @Test func staysOnTheScreenAtItsSides() {
        let left = NSRect(x: -20, y: 400, width: 120, height: 120)
        let right = NSRect(x: 1_380, y: 400, width: 120, height: 120)
        #expect(RadialLabel.frame(width: 180, below: left, on: Self.screen).minX == 0)
        #expect(RadialLabel.frame(width: 180, below: right, on: Self.screen).maxX == 1_440)
    }

    @Test func showsTheTextAndHidesAgain() {
        label.show("Left Third", below: NSRect(x: 640, y: 400, width: 120, height: 120))
        defer { label.hide() }
        #expect(label.panel.isVisible)
        #expect(label.text.stringValue == "Left Third")
        #expect(label.panel.contentView?.accessibilityLabel() == "Left Third")
        #expect(label.panel.frame.height == 26)
        #expect(label.panel.frame.width > 26)

        label.hide()
        #expect(!label.panel.isVisible)
    }
}
