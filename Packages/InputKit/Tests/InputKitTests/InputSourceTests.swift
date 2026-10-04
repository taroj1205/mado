import Carbon.HIToolbox
import Testing

@testable import InputKit

@MainActor
@Suite struct InputSourceTests {
    @Test func listsTheCurrentKeyboardSourceAmongTheEnabledOnes() throws {
        let current = try #require(InputSource.currentID)
        let source = try #require(InputSource.enabled.first { $0.id == current })

        #expect(!source.name.isEmpty)
        #expect(InputSource.named(current) == source.name)
    }

    @Test func ignoresASourceThatIsNotEnabled() throws {
        let current = try #require(InputSource.currentID)

        InputSource.select("com.example.not-a-source")

        #expect(InputSource.currentID == current)
        #expect(InputSource.named("com.example.not-a-source") == nil)
    }

    @Test func typesASCIIExactlyWhenTheCurrentSourceIsTheASCIIOne() throws {
        let ascii = try #require(
            unsafe TISCopyCurrentASCIICapableKeyboardInputSource()?.takeRetainedValue())

        let isCurrent =
            InputSource.string(ascii, kTISPropertyInputSourceID) == InputSource.currentID

        #expect(InputSource.currentTypesASCII == isCurrent)
    }

    @Test func nextSourceWrapsAroundAndStartsAtTheFirstWhenTheCurrentIsUnknown() {
        let ids = ["abc", "kana", "us"]
        let later = ContinuousClock.now + .seconds(5)

        for (current, expected) in [("abc", "kana"), ("us", "abc"), ("gone", "abc")] {
            var cycle = InputCycle()
            #expect(cycle.next(after: current, in: ids, at: later) == expected)
        }
        var cycle = InputCycle()
        #expect(cycle.next(after: nil, in: ids, at: later) == "abc")
        #expect(cycle.next(after: "abc", in: [], at: later) == nil)
    }

    @Test func aQuickSecondTapMovesOnWhileTheSystemStillReportsTheOldSource() {
        let ids = ["abc", "kana", "us"]
        let start = ContinuousClock.now
        var cycle = InputCycle()

        #expect(cycle.next(after: "abc", in: ids, at: start) == "kana")
        #expect(cycle.next(after: "abc", in: ids, at: start + .milliseconds(300)) == "us")
        #expect(cycle.next(after: "us", in: ids, at: start + .milliseconds(600)) == "abc")
        #expect(cycle.next(after: "abc", in: ids, at: start + .seconds(3)) == "kana")
    }
}
