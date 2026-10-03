import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetGalleryTests {
    private let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 920, height: 640),
        styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: true)
    private let gallery = WidgetGallery(
        cards: ["clock", "system", "battery", "keep_awake", "timer", "music"].map { id in
            WidgetGallery.Card(
                id: id, name: id.capitalized, summary: "About \(id)", size: .small,
                group: Self.group(of: id), symbol: "clock",
                colour: .gray)
        })

    init() {
        window.contentView = gallery
        gallery.added = ["clock", "system"]
        gallery.layoutSubtreeIfNeeded()
    }

    private static func group(of id: String) -> WidgetGallery.Group? {
        switch id {
        case "clock", "timer": .time
        case "music": nil
        default: .system
        }
    }

    private static func texts(in view: NSView) -> [String] {
        let own = (view as? NSTextField).map { [$0.stringValue] } ?? []
        return own + view.subviews.flatMap(texts)
    }

    private func card(_ id: String) throws -> WidgetGalleryCard {
        try #require(gallery.cards.first { $0.card.id == id })
    }

    private func pick(_ segment: Int) {
        gallery.filter.selectedSegment = segment
        gallery.filter.sendAction(gallery.filter.action, to: gallery.filter.target)
        gallery.layoutSubtreeIfNeeded()
    }

    @Test func cardsSitFourToARowWithTheirDetails() throws {
        let first = try card("clock")
        let frames = try ["clock", "keep_awake", "timer"].map { id in
            let card = try card(id)
            return card.convert(card.bounds, to: nil)
        }
        #expect(abs(frames[0].width - (920 - 40 - 30) / 4) <= 1)
        #expect(abs(frames[0].minX - 20) <= 1)
        #expect(abs(frames[1].maxX - 900) <= 1)
        #expect(frames[1].minY == frames[0].minY)
        #expect(abs(frames[0].minY - frames[2].maxY - 10) <= 1)
        #expect(abs(frames[2].width - frames[0].width) <= 1)
        let texts = first.subviews.flatMap(\.subviews).flatMap(Self.texts)
        #expect(texts.contains("Clock"))
        #expect(texts.contains("About clock"))
        #expect(texts.contains("Small"))
        #expect(first.accessibilityLabel() == "Clock")
    }

    @Test func addedCardsSayAddedAndTheOthersOfferAdd() throws {
        #expect(try card("clock").add.isHidden)
        #expect(try !card("clock").added.isHidden)
        #expect(try !card("battery").add.isHidden)
        #expect(try card("battery").added.isHidden)
        #expect(try card("battery").add.accessibilityLabel() == "Add Battery")
        #expect(gallery.count.stringValue == "2 widgets on the empty query")
    }

    @Test func addReportsTheCardAndTheGalleryShowsTheNewList() throws {
        var adds: [String] = []
        gallery.onAdd = { adds.append($0) }
        try card("battery").add.performClick(nil)
        #expect(adds == ["battery"])
        gallery.added = ["clock", "system", "battery"]
        #expect(try card("battery").add.isHidden)
        #expect(gallery.count.stringValue == "3 widgets on the empty query")
        gallery.added = ["clock"]
        #expect(gallery.count.stringValue == "1 widget on the empty query")
    }

    @Test func theCountSaysCardsCanBeDraggedOnlyWhenTheLauncherIsWaitingForThem() {
        gallery.hintsDrag = true
        #expect(
            gallery.count.stringValue
                == "2 widgets on the empty query · drag a card onto the launcher to place it")
        gallery.hintsDrag = false
        #expect(gallery.count.stringValue == "2 widgets on the empty query")
    }

    @Test func theFilterNarrowsTheCardsToOneGroup() {
        #expect(gallery.filter.segmentCount == 4)
        #expect(gallery.filter.label(forSegment: 3) == "From extensions")
        pick(1)
        #expect(gallery.shown.map(\.card.id) == ["clock", "timer"])
        #expect(gallery.grid.arrangedSubviews.count == 1)
        pick(2)
        #expect(gallery.shown.map(\.card.id) == ["system", "battery", "keep_awake"])
        #expect(gallery.empty.isHidden)
        pick(3)
        #expect(gallery.shown.isEmpty)
        #expect(gallery.grid.arrangedSubviews.isEmpty)
        #expect(!gallery.empty.isHidden)
        let emptyText = gallery.empty.arrangedSubviews.flatMap(Self.texts)
        #expect(emptyText == ["No widgets from extensions yet"])
        pick(0)
        #expect(gallery.empty.isHidden)
        #expect(gallery.shown.map(\.card.id).last == "music")
        #expect(gallery.grid.arrangedSubviews.count == 2)
    }

    @Test func sizesShowTheirFootprintInCells() {
        #expect(WidgetGallery.Size.small.footprint.size == NSSize(width: 5, height: 5))
        #expect(WidgetGallery.Size.wide.footprint.size == NSSize(width: 11.5, height: 5))
        #expect(WidgetGallery.Size.large.footprint.size == NSSize(width: 11.5, height: 11.5))
        #expect(WidgetGallery.Size.wide.footprint.isTemplate)
    }

    @Test func theFooterKeepsItsHeightWhateverTheGridShows() {
        let done = gallery.done
        let height = { done.convert(done.bounds, to: nil).minY }
        let resting = height()
        gallery.added = ["clock", "system", "battery", "keep_awake"]
        gallery.layoutSubtreeIfNeeded()
        #expect(height() == resting)
        pick(3)
        #expect(height() == resting)
        #expect(abs(resting - 14) <= 1)
        let count = gallery.count.convert(gallery.count.bounds, to: nil)
        #expect(count.height < done.bounds.height)
        #expect(abs(count.midY - done.convert(done.bounds, to: nil).midY) <= 1)
    }

    @Test func doneFinishesAndIsTheDefaultButton() {
        var finished = 0
        gallery.onDone = { finished += 1 }
        gallery.done.performClick(nil)
        #expect(finished == 1)
        #expect(gallery.done.keyEquivalent == "\r")
    }
}
