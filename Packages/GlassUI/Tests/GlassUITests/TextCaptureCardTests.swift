import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite(.silentWindows) struct TextCaptureCardTests {
    private let card = TextCaptureCard()

    private func show(_ result: TextCaptureCard.Result) {
        card.show(result) { CGRect(origin: CGPoint(x: 100, y: 100), size: $0) }
    }

    @Test func showsWhatWasCopiedWithItsLanguage() {
        show(.copied(text: "Flat white ... 5.50\nTOTAL ... 12.30", language: "en"))
        defer { card.hide() }

        #expect(card.title.stringValue == "Text copied")
        #expect(card.text.stringValue == "Flat white ... 5.50\nTOTAL ... 12.30")
        #expect(card.note.stringValue.hasSuffix(" · on device"))
        #expect(card.note.stringValue.count > " · on device".count)
        #expect(card.hint.stringValue == "The text is already on your clipboard")
        #expect(!card.box.isHidden)
        #expect(card.panel.isVisible)
        #expect(card.panel.ignoresMouseEvents)
        #expect(card.panel.frame.width == TextCaptureCard.width)
        #expect(card.text.maximumNumberOfLines == TextCaptureCard.shownLines)
    }

    @Test func leavesOutTheLanguageWhenItIsNotKnown() {
        show(.copied(text: "12.30", language: nil))
        defer { card.hide() }

        #expect(card.note.stringValue == "On device")
    }

    @Test func saysNothingWasFoundAndHidesTheTextBox() {
        show(.nothingFound)
        defer { card.hide() }

        #expect(card.title.stringValue == "No text found")
        #expect(card.note.stringValue.isEmpty)
        #expect(card.hint.stringValue == "Nothing was copied · try a larger or sharper area")
        #expect(card.box.isHidden)
    }

    @Test func aLongTextStopsGrowingAtTheLastShownLine() {
        func height(ofLines count: Int) -> CGFloat {
            show(
                .copied(
                    text: (1...count).map { "line \($0)" }.joined(separator: "\n"), language: "en"))
            return card.panel.frame.height
        }
        defer { card.hide() }

        #expect(height(ofLines: 1) < height(ofLines: TextCaptureCard.shownLines))
        #expect(height(ofLines: 30) == height(ofLines: TextCaptureCard.shownLines))
    }

    @Test func comesBackAfterBeingHidden() {
        show(.nothingFound)
        card.hide()
        #expect(!card.panel.isVisible)

        show(.copied(text: "12.30", language: "en"))
        defer { card.hide() }
        #expect(card.panel.isVisible)
        #expect(card.stack.accessibilityLabel() == "Text copied: 12.30")
    }
}
