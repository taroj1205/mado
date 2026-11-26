import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite(.silentWindows) struct DictationPillLiveTextTests {
    private let pill = DictationPill()

    private var shown: [NSView] {
        pill.stack.arrangedSubviews.filter { !$0.isHidden }
    }

    init() {
        pill.reducesMotion = { false }
    }

    @Test func liveTextFollowsTheTimeAndKeepsTheNewestWords() {
        pill.show(.listening(since: .now), on: nil)
        defer { pill.hide() }
        let narrow = pill.stack.fittingSize.width
        pill.showLiveText("save me a seat")
        #expect(shown == [pill.dot, pill.meter, pill.clock, pill.caption])
        #expect(pill.caption.stringValue == "save me a seat")
        #expect(pill.caption.lineBreakMode == .byTruncatingHead)
        #expect(pill.stack.accessibilityLabel() == "Listening, save me a seat")
        pill.showLiveText(String(repeating: "Running ten minutes late. ", count: 20))
        #expect(pill.stack.fittingSize.width <= narrow + 10 + 300)
    }

    @Test func liveTextOnlyShowsWhileListening() {
        pill.show(.transcribing, on: nil)
        defer { pill.hide() }
        pill.showLiveText("save me a seat")
        #expect(shown == [pill.spinner, pill.title])
        #expect(pill.caption.stringValue.isEmpty)
    }

    @Test func aNewRecordingStartsWithoutLiveText() {
        pill.show(.listening(since: .now), on: nil)
        defer { pill.hide() }
        pill.showLiveText("save me a seat")
        pill.show(.listening(since: .now), on: nil)
        #expect(shown == [pill.dot, pill.meter, pill.clock])
        #expect(pill.caption.stringValue.isEmpty)
        #expect(pill.stack.accessibilityLabel() == "Listening")
    }

    @Test func emptyLiveTextHidesTheCaption() {
        pill.show(.listening(since: .now), on: nil)
        defer { pill.hide() }
        pill.showLiveText("save me a seat")
        pill.showLiveText("")
        #expect(shown == [pill.dot, pill.meter, pill.clock])
        #expect(pill.stack.accessibilityLabel() == "Listening")
    }
}
