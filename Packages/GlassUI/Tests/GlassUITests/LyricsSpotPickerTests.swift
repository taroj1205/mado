import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite(.silentWindows)
struct LyricsSpotPickerTests {
    private final class Store {
        var spot: LyricsSpot?
        var writes = 0
    }

    private let store = Store()

    private func picker(_ start: LyricsSpot? = nil) -> LyricsSpotPicker {
        store.spot = start
        let kept = store
        let picker = LyricsSpotPicker(
            read: { kept.spot },
            write: { spot in
                kept.spot = spot
                kept.writes += 1
            })
        picker.frame = NSRect(x: 0, y: 0, width: 640, height: 260)
        picker.layoutSubtreeIfNeeded()
        return picker
    }

    @Test func eachSpotSitsInsideTheScreenAndNoTwoOverlap() {
        let screen = CGRect(x: 0, y: 0, width: LyricsSpotMap.width, height: LyricsSpotMap.height)
        let frames = LyricsSpot.all.compactMap { LyricsSpotMap.frames[$0] }
        #expect(frames.count == LyricsSpot.all.count)
        #expect(frames.allSatisfy { screen.contains($0) })
        for (index, frame) in frames.enumerated() {
            for other in frames[(index + 1)...] {
                #expect(!frame.intersects(other))
            }
        }
    }

    @Test func theMiddleOfEachSpotHitsThatSpot() {
        let map = LyricsSpotMap()
        for spot in LyricsSpot.all {
            guard let frame = LyricsSpotMap.frames[spot] else { continue }
            #expect(map.spot(at: NSPoint(x: frame.midX, y: frame.midY)) == spot)
        }
        #expect(
            map.spot(at: NSPoint(x: LyricsSpotMap.width * 0.5, y: LyricsSpotMap.height * 0.4))
                == nil)
    }

    @Test func showsWhatIsStoredAndFollowsItWhenItChanges() {
        let view = picker(.dock(.leading))
        #expect(view.map.selection == .dock(.leading))
        #expect(!view.off.isHidden)
        store.spot = .island
        view.refresh()
        #expect(view.map.selection == .island)
        store.spot = nil
        view.refresh()
        #expect(view.map.selection == nil)
        #expect(view.off.isHidden)
        #expect(store.writes == 0)
    }

    @Test func pickingASpotWritesItOnceAndTellsTheOwner() {
        let view = picker()
        var changes = 0
        view.onChange = { changes += 1 }
        view.map.onPick?(.corner(.topLeading))
        #expect(store.spot == .corner(.topLeading))
        #expect(store.writes == 1)
        #expect(changes == 1)
        #expect(view.map.selection == .corner(.topLeading))
    }

    @Test func turningOffWritesNoSpotAndHidesItsOwnButton() {
        let view = picker(.island)
        view.off.performClick(nil)
        #expect(store.spot == nil)
        #expect(store.writes == 1)
        #expect(view.off.isHidden)
        #expect(view.map.selection == nil)
    }

    @Test func aDisabledPickerDimsAndStopsHits() {
        let view = picker(.island)
        view.isEnabled = false
        #expect(view.alphaValue < 1)
        #expect(!view.off.isEnabled)
        #expect(view.map.spot(at: NSPoint(x: 20, y: 40)) == nil)
        view.isEnabled = true
        #expect(view.alphaValue == 1)
    }
}
