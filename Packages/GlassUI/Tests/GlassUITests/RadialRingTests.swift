import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct RadialRingTests {
    private let ring = RadialRing()

    @Test func turnsTheShortWayAcrossZero() {
        ring.select(.direction(degrees: 315))
        ring.select(.direction(degrees: 0))
        #expect(ring.arcDegrees == 360)
        ring.select(.direction(degrees: 45))
        #expect(ring.arcDegrees == 405)
        ring.select(.direction(degrees: 270))
        #expect(ring.arcDegrees == 270)
    }

    @Test func keepsTheArcsAngleWhileOffTheDirections() {
        ring.select(.direction(degrees: 315))
        ring.select(.ring)
        ring.select(.direction(degrees: 0))
        #expect(ring.arcDegrees == 360)
    }

    @Test func opensInTheHoleWithTheCrossAndDimmedGlass() {
        ring.select(.ring)
        ring.appear()
        #expect(ring.highlight == .cancel)
        #expect(ring.cross.opacity == 1)
        #expect(ring.band.opacity == 0)
        #expect(ring.arc.opacity == 0)
        #expect(ring.glass.alphaValue == 0.75)
    }

    @Test func showsOnlyTheMarkOfTheZone() {
        ring.select(.ring)
        #expect([ring.cross.opacity, ring.band.opacity, ring.arc.opacity] == [0, 1, 0])
        ring.select(.direction(degrees: 90))
        #expect([ring.cross.opacity, ring.band.opacity, ring.arc.opacity] == [0, 0, 1])
        #expect(ring.glass.alphaValue == 1)
    }

    @Test func centresItsFrameOnWholePoints() {
        #expect(
            RadialRing.frame(centredOn: CGPoint(x: 700.4, y: 400.6))
                == NSRect(x: 640, y: 341, width: 120, height: 120))
    }
}
