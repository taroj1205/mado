import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite struct EmojiGridTests {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 760, height: 580),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let view = LauncherView()

    init() {
        panel.contentView = view
        panel.makeFirstResponder(view.field)
    }

    private static func emoji(_ glyph: String, _ name: String) -> ResultList.Item {
        var item = ResultList.Item(
            id: "emoji.\(glyph)", title: name, subtitle: ":\(name):", kind: "", symbol: "",
            action: "Paste")
        item.glyph = glyph
        return item
    }

    private static func sections() -> [ResultList.Section] {
        var matching = ResultList.Section(
            title: "Matching “heart”", items: [emoji("💙", "blue_heart"), emoji("💜", "purple")])
        matching.selectsFirst = true
        return [.init(title: "Recently used", items: [emoji("👍", "thumbs")]), matching]
    }

    @Test func movesByColumnsAndAcrossSections() {
        let counts = [3, 0, 14, 5]
        let step = { (item: Int, section: Int, direction: EmojiGrid.Direction) in
            EmojiGrid.step(
                from: IndexPath(item: item, section: section), direction, counts: counts,
                columns: 12)
        }

        #expect(step(2, 0, .right) == IndexPath(item: 0, section: 2))
        #expect(step(0, 2, .left) == IndexPath(item: 2, section: 0))
        #expect(step(0, 0, .left) == nil)
        #expect(step(1, 0, .below) == IndexPath(item: 1, section: 2))
        #expect(step(5, 2, .below) == IndexPath(item: 13, section: 2))
        #expect(step(13, 2, .below) == IndexPath(item: 1, section: 3))
        #expect(step(13, 2, .above) == IndexPath(item: 1, section: 2))
        #expect(step(4, 3, .above) == IndexPath(item: 13, section: 2))
        #expect(step(10, 2, .above) == IndexPath(item: 2, section: 0))
        #expect(step(4, 3, .below) == nil)
    }

    @Test func showsTheGridInPlaceOfTheListAndStartsOnTheFirstMatch() {
        var grids: [Bool] = []
        view.onGridChange = { grids.append($0) }
        view.capsuleSlots = [.keyed(LauncherView.Action.secondaryKeys), .primary, .actions]
        view.actions = { _ in [.init("Paste", keys: ["↵"]), .init("Copy", keys: ["⌘", "↵"])] }

        view.show(Self.sections(), gridHome: ":")
        view.layoutSubtreeIfNeeded()

        #expect(view.showsGrid && grids == [true])
        #expect(view.results.isHidden && !view.emojiGrid.isHidden)
        #expect(view.selectedItem?.title == "blue_heart")
        #expect(view.contextPill.text == "💙  blue_heart · :blue_heart:")
        let stack = view.actionCapsule.contentView as? NSStackView
        #expect((stack?.arrangedSubviews.first as? CapsuleButton)?.accessibilityLabel() == "Copy")
        #expect(stack?.arrangedSubviews.last === view.actionsToggle)

        view.show([.init(title: "Results", items: [Self.emoji("x", "row")])])

        #expect(!view.showsGrid && grids == [true, false])
        #expect(!view.results.isHidden && view.emojiGrid.isHidden)
        #expect(view.selectedItem?.title == "row")
    }

    @Test func arrowsMoveTheGridSelectionAndReturnRunsIt() {
        var runs: [(String, Int)] = []
        view.onRun = { runs.append(($0.title, $1)) }
        view.show(Self.sections(), gridHome: "")

        press(kVK_RightArrow, "\u{F703}")
        #expect(view.selectedItem?.title == "purple")
        press(kVK_UpArrow, "\u{F700}")
        #expect(view.selectedItem?.title == "thumbs")
        press(kVK_Return, "\r")

        #expect(runs.map(\.0) == ["thumbs"] && runs.map(\.1) == [0])
    }

    @Test func aRefreshKeepsTheEmojiTheArrowsMovedTo() {
        view.show(Self.sections(), gridHome: "")
        press(kVK_RightArrow, "\u{F703}")

        view.show(Self.sections(), gridHome: "")

        #expect(view.selectedItem?.title == "purple")
    }

    @Test func aRefreshKeepsTheEmojiATabJumpedTo() {
        view.emojiGrid.tabs = [.init(title: "Recent", symbol: "clock", section: "Recently used")]
        view.show(Self.sections(), gridHome: "")
        view.emojiGrid.onTab?(view.emojiGrid.tabs[0])

        view.show(Self.sections(), gridHome: "")

        #expect(view.selectedItem?.title == "thumbs")
        #expect(view.emojiGrid.tabBar.arrangedSubviews.count == 1)
    }

    @Test func movingDownKeepsTheSelectedEmojiOnScreen() throws {
        let many = (0..<240).map { Self.emoji("😀", "face\($0)") }
        view.show([.init(title: "Smileys", items: many)], gridHome: "")
        view.layoutSubtreeIfNeeded()
        for _ in 0..<12 {
            press(kVK_DownArrow, "\u{F701}")
        }
        view.layoutSubtreeIfNeeded()
        let grid = view.emojiGrid.collection
        let selected = try #require(grid.selectionIndexPaths.first)
        let frame = try #require(grid.layoutAttributesForItem(at: selected)?.frame)

        #expect(selected.item == 144)
        #expect(grid.visibleRect.intersects(frame))
    }

    @Test func voiceOverPressingAnEmojiPicksIt() throws {
        var runs: [String] = []
        view.onRun = { item, _ in runs.append(item.title) }
        view.show(Self.sections(), gridHome: "")
        view.layoutSubtreeIfNeeded()
        let grid = view.emojiGrid.collection
        let cell = try #require(grid.item(at: IndexPath(item: 1, section: 1)))

        #expect(cell.view.accessibilityPerformPress())
        #expect(runs == ["purple"])
        #expect(view.selectedItem?.title == "purple")
    }

    @Test func anEmptyGridLetsLeftAndRightMoveTheCaret() {
        let notice = ResultList.Notice(title: "No emoji match “zz”", detail: "")
        view.show([.init(title: "", items: [], notice: notice)], gridHome: ":")

        #expect(!view.gridCommand(#selector(NSResponder.moveLeft)))
        #expect(view.gridCommand(#selector(NSResponder.moveDown)))
    }

    @Test func aMatchingSectionHighlightsNoTab() {
        view.emojiGrid.tabs = [.init(title: "Recent", symbol: "clock", section: "Recently used")]
        view.show(Self.sections(), gridHome: ":")

        let tabs = view.emojiGrid.tabBar.arrangedSubviews.compactMap { $0 as? EmojiTab }
        #expect(tabs.allSatisfy { !$0.isOn })
    }

    @Test func pickingWithNowhereToPasteCopies() throws {
        var runs: [Int] = []
        view.onRun = { runs.append($1) }
        view.actions = { _ in [.init("Copy", keys: LauncherView.Action.secondaryKeys)] }
        var copyOnly = ResultList.Item(
            id: "emoji.copy", title: "red", subtitle: "", kind: "", symbol: "", action: "")
        copyOnly.glyph = "❤️"
        view.show([.init(title: "Recently used", items: [copyOnly])], gridHome: "")
        view.layoutSubtreeIfNeeded()
        let cell = try #require(view.emojiGrid.collection.item(at: IndexPath(item: 0, section: 0)))

        #expect(cell.view.accessibilityPerformPress())
        #expect(runs == [0])
    }

    @Test func pickingATabOfAMissingSectionGoesBackToTheHomeQuery() {
        var queries: [String] = []
        view.onQuery = { queries.append($0) }
        view.emojiGrid.tabs = [.init(title: "Recent", symbol: "clock", section: "Recently used")]
        view.field.stringValue = ":heart"
        view.show([.init(title: "Matching", items: [Self.emoji("💙", "blue")])], gridHome: ":")

        view.emojiGrid.onTab?(view.emojiGrid.tabs[0])
        view.show(Self.sections(), gridHome: ":")

        #expect(queries == [":"])
        #expect(view.selectedItem?.title == "thumbs")
    }

    private func press(_ keyCode: Int, _ characters: String) {
        guard
            let event = NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: panel.windowNumber, context: nil, characters: characters,
                charactersIgnoringModifiers: characters, isARepeat: false,
                keyCode: UInt16(keyCode))
        else {
            Issue.record("Could not make a key event for \(keyCode)")
            return
        }
        panel.sendEvent(event)
    }
}
