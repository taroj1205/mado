import Testing

@testable import GlassUI

struct LyricsSpotTests {
    @Test func everyPinHasASpotAndDockAndCornersHaveMore() {
        let pins = Set(LyricsSpot.all.map(\.pin))
        #expect(pins == Set(LyricsPin.allCases))
        #expect(LyricsSpot.all.count == 10)
        #expect(Set(LyricsSpot.all).count == LyricsSpot.all.count)
    }

    @Test func aSpotRoundTripsThroughThePinCornerAndSideItIsStoredAs() {
        for spot in LyricsSpot.all {
            let stored = LyricsSpot(
                pin: spot.pin, corner: spot.corner ?? .bottomTrailing, side: spot.side ?? .trailing)
            #expect(stored == spot)
        }
    }

    @Test func onlyCornersAndTheDockCarryAPlace() {
        #expect(LyricsSpot.corner(.topLeading).corner == .topLeading)
        #expect(LyricsSpot.corner(.topLeading).side == nil)
        #expect(LyricsSpot.dock(.leading).side == .leading)
        #expect(LyricsSpot.dock(.leading).corner == nil)
        #expect(LyricsSpot.island.corner == nil)
        #expect(LyricsSpot.island.side == nil)
    }

    @Test func titlesNameTheCornerAndTheSide() {
        #expect(LyricsSpot.corner(.topLeading).title == "Corner card · Top Left")
        #expect(LyricsSpot.dock(.trailing).title == "Next to the Dock · Right")
        #expect(LyricsSpot.island.title == "Island")
        #expect(LyricsSpot.all.allSatisfy { !$0.detail.isEmpty })
    }

    @Test func theOtherSideIsTheOppositeOne() {
        #expect(LyricsSide.leading.other == .trailing)
        #expect(LyricsSide.trailing.other == .leading)
    }
}
