import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct ArtworkTintTests {
    private func cover(_ paint: @escaping (NSRect) -> Void) -> NSImage {
        NSImage(size: NSSize(width: 40, height: 40), flipped: false) { rect in
            paint(rect)
            return true
        }
    }

    @Test func aColourfulCoverGivesItsColourAtAUsableStrength() throws {
        let teal = cover { rect in
            NSColor(srgbRed: 0.1, green: 0.7, blue: 0.7, alpha: 1).setFill()
            rect.fill()
        }
        let tint = try #require(ArtworkTint.of(teal)?.usingColorSpace(.sRGB))
        #expect(abs(tint.hueComponent - 0.5) < 0.03)
        #expect(tint.saturationComponent >= 0.45)
        #expect(tint.brightnessComponent >= 0.4)
    }

    @Test func theVividPartOfACoverOutweighsItsDullBackground() throws {
        let mostlyGrey = cover { rect in
            NSColor.darkGray.setFill()
            rect.fill()
            NSColor.red.setFill()
            NSRect(x: 0, y: 0, width: 14, height: 40).fill()
        }
        let tint = try #require(ArtworkTint.of(mostlyGrey)?.usingColorSpace(.sRGB))
        #expect(tint.saturationComponent > 0.4)
        #expect(tint.hueComponent < 0.04 || tint.hueComponent > 0.96)
    }

    @Test func aGreyCoverStaysGreyInsteadOfInventingAHue() throws {
        let grey = cover { rect in
            NSColor.gray.setFill()
            rect.fill()
        }
        let tint = try #require(ArtworkTint.of(grey)?.usingColorSpace(.sRGB))
        #expect(tint.saturationComponent < 0.01)
    }

    @Test func aFullyTransparentCoverHasNoTint() {
        #expect(ArtworkTint.of(cover { _ in _ = 0 }) == nil)
    }
}
