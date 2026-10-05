import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite struct LauncherSplitTests {
    private final class FilterSpy: NSPopUpButton {
        var clicks = 0

        override func performClick(_: Any?) {
            clicks += 1
        }
    }

    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 760, height: 476),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let view = LauncherView()
    private let filter = FilterSpy(frame: .zero, pullsDown: false)

    init() {
        panel.contentView = view
        view.results.reducesMotion = { true }
        filter.addItem(withTitle: "All Types")
        panel.makeFirstResponder(view.field)
    }

    private static func item(
        _ title: String, tint: NSColor? = nil, action: String = ""
    ) -> ResultList.Item {
        .init(
            id: title, title: title, subtitle: "", kind: "Text", symbol: "text.alignleft",
            action: action, tint: tint)
    }

    private static func png() throws -> URL {
        let file = FileManager.default.temporaryDirectory.appending(path: "\(UUID()).png")
        let drawn = NSImage(size: NSSize(width: 4, height: 4), flipped: false) { rect in
            NSColor.systemBlue.setFill()
            rect.fill()
            return true
        }
        let bitmap = try #require(drawn.tiffRepresentation.flatMap(NSBitmapImageRep.init))
        try #require(bitmap.representation(using: .png, properties: [:])).write(to: file)
        return file
    }

    private static func preview(of item: ResultList.Item) -> LauncherView.Preview {
        .init(
            text: "\(item.title) text", image: nil,
            details: [("Source", "Notes"), ("Content type", "Text")])
    }

    private func enter() {
        view.enter(
            placeholder: "Type to filter entries…", filter: filter, detail: .preview(Self.preview))
        view.show([.init(title: "Today", items: [Self.item("first"), Self.item("second")])])
        view.layoutSubtreeIfNeeded()
    }

    @Test func splitsTheListFromAPreviewOfTheSelectedRow() throws {
        enter()

        #expect(view.results.frame.minX == 8)
        #expect(view.results.frame.width == 280)
        #expect(!view.detail.isHidden)
        #expect(view.detail.frame.minX == 295)
        #expect(view.detail.frame.maxX == 760)
        #expect(view.detail.text.stringValue == "first text")
        #expect(view.results.table.rect(ofRow: 1).height == 36 + ResultList.rowGap)
        let cell = try #require(
            view.results.table.view(atColumn: 0, row: 1, makeIfNecessary: true) as? GlyphCell)
        #expect(cell.title.stringValue == "first")
        #expect(cell.accessibilityLabel() == "first, Text")
        press(kVK_DownArrow, "\u{F701}")
        view.layoutSubtreeIfNeeded()
        #expect(view.detail.text.stringValue == "second text")
        let header = try #require(view.detail.info.arrangedSubviews.first)
        #expect(header.frame.height == header.fittingSize.height)
        let title = try #require(header.subviews.first)
        #expect(title.alignmentRect(forFrame: title.frame).minX == 2)
        let rows = view.detail.info.arrangedSubviews.dropFirst()
        #expect(rows.map { $0.accessibilityLabel() } == ["Source, Notes", "Content type, Text"])
        #expect(rows.allSatisfy { $0.frame.height == 30 })
    }

    @Test func thePreviewEmptiesWithoutAnEntry() {
        enter()
        view.results.sections = [
            .init(
                title: "", items: [],
                notice: .init(title: "No clipboard history yet", detail: "Copy something."))
        ]
        #expect(view.detail.box.isHidden)
        #expect(view.detail.info.isHidden)
        #expect(!view.detail.isHidden)
    }

    @Test func showsAnImageInPlaceOfTextAndLetsGoOfItOnLeaving() async throws {
        let file = try Self.png()
        defer { try? FileManager.default.removeItem(at: file) }
        let thumbnail = Thumbnails.Request(url: file, side: 48)
        #expect(await Thumbnails.shared.load(thumbnail) != nil)
        view.enter(
            placeholder: "Filter",
            detail: .preview { _ in .init(text: "", image: file, details: []) })
        view.results.sections = [.init(title: "Today", items: [Self.item("image")])]
        #expect(!view.detail.image.isHidden)
        #expect(view.detail.text.isHidden)
        await view.detail.loading?.value
        let shown = try #require(view.detail.image.image)
        let loading = view.detail.loading

        view.refreshDetail()

        #expect(view.detail.image.image === shown)
        #expect(view.detail.loading == loading)

        view.leave()

        #expect(view.detail.image.image == nil)
        #expect(Thumbnails.shared.cached(thumbnail) == nil)
    }

    @Test func aPreviewStillLoadingIsDroppedWhenTheSelectionMoves() async throws {
        let file = try Self.png()
        defer { try? FileManager.default.removeItem(at: file) }
        view.enter(
            placeholder: "Filter",
            detail: .preview { item in
                .init(text: item.title, image: item.id == "image" ? file : nil, details: [])
            })
        view.results.sections = [
            .init(title: "Today", items: [Self.item("image"), Self.item("text")])
        ]
        let stale = try #require(view.detail.loading)

        press(kVK_DownArrow, "\u{F701}")
        await stale.value

        #expect(view.detail.loading == nil)
        #expect(view.detail.image.image == nil)
        #expect(view.detail.image.isHidden)
        #expect(view.detail.text.stringValue == "text")
    }

    @Test func leavingWhileAThumbnailLoadsKeepsItOutOfTheCache() async throws {
        let file = try Self.png()
        defer { try? FileManager.default.removeItem(at: file) }
        enter()
        let image = ResultList.Item(
            id: "image", title: "Image", subtitle: "", kind: "Image", symbol: "photo", action: "",
            thumbnail: file)
        view.results.sections = [.init(title: "Today", items: [image])]
        let cell = try #require(
            view.results.table.view(atColumn: 0, row: 1, makeIfNecessary: true) as? GlyphCell)
        let loading = try #require(cell.loading)

        view.leave()
        await loading.value

        let side = Int((GlyphCell.thumbnailSize * panel.backingScaleFactor).rounded(.up))
        #expect(Thumbnails.shared.cached(.init(url: file, side: side)) == nil)
    }

    @Test func refreshingTheDetailAsksForTheSelectedRowAgain() {
        var words = "…"
        view.enter(
            placeholder: "Filter", filter: filter,
            detail: .preview { item in
                .init(text: item.title, image: nil, details: [("Words", words)])
            })
        view.results.sections = [.init(title: "Today", items: [Self.item("first")])]
        let row = { view.detail.info.arrangedSubviews.last?.accessibilityLabel() }
        #expect(row() == "Words, …")

        words = "6"
        view.refreshDetail()

        #expect(row() == "Words, 6")
        #expect(view.detail.text.stringValue == "first")
    }

    @Test func theFilterSitsAtTheEndOfTheBarAndCommandPOpensIt() {
        enter()

        #expect(view.subviews.contains(filter))
        #expect(filter.frame.maxX <= view.bounds.maxX - 14)
        #expect(
            view.field.alignmentRect(forFrame: view.field.frame).maxX
                == filter.alignmentRect(forFrame: filter.frame).minX - 12)
        press(kVK_ANSI_P, "p", [.command])
        #expect(filter.clicks == 1)
    }

    @Test func goingBackRestoresTheFullWidthList() {
        var leaves = 0
        view.onLeave = { leaves += 1 }
        enter()
        view.leave()
        view.leave()
        view.layoutSubtreeIfNeeded()

        #expect(!view.subviews.contains(filter))
        #expect(view.detail.isHidden)
        #expect(!view.results.compact)
        #expect(view.results.frame.width == 744)
        #expect(
            view.field.alignmentRect(forFrame: view.field.frame).maxX == view.bounds.maxX - 20)
        press(kVK_ANSI_P, "p", [.command])
        #expect(filter.clicks == 0)
        #expect(leaves == 1)
    }

    @Test func aRowWithoutAPrimaryActionShowsOnlyActionsAndReturnDoesNothing() {
        var runs: [Int] = []
        view.onRun = { runs.append($1) }
        enter()
        let stack = view.actionCapsule.contentView as? NSStackView

        #expect(!view.actionCapsule.isHidden)
        #expect(stack?.arrangedSubviews.filter { !$0.isHidden } == [view.actionsToggle])
        #expect(stack?.edgeInsets.left == 5)
        press(kVK_Return, "\r")
        #expect(runs.isEmpty)
        view.show([.init(title: "Today", items: [Self.item("x", action: "Paste")])])
        #expect(stack?.arrangedSubviews.allSatisfy { !$0.isHidden } == true)
        #expect(stack?.edgeInsets.left == 17)
        press(kVK_Return, "\r")
        #expect(runs == [0])
    }

    @Test func aColourRowTintsItsGlyph() throws {
        enter()
        view.results.sections = [
            .init(title: "Today", items: [Self.item("#0A84FF", tint: .systemBlue)])
        ]
        let cell = try #require(
            view.results.table.view(atColumn: 0, row: 1, makeIfNecessary: true) as? GlyphCell)
        #expect(cell.glyph.contentTintColor == .systemBlue)
    }

    private func press(
        _ keyCode: Int, _ characters: String, _ modifiers: NSEvent.ModifierFlags = []
    ) {
        guard
            let event = NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
                windowNumber: panel.windowNumber, context: nil, characters: characters,
                charactersIgnoringModifiers: characters, isARepeat: false,
                keyCode: UInt16(keyCode))
        else {
            Issue.record("Could not make a key event for \(keyCode)")
            return
        }
        if modifiers.contains(.command), panel.performKeyEquivalent(with: event) { return }
        panel.sendEvent(event)
    }
}
