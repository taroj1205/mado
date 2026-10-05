import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite struct EventCellTests {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 760, height: 476),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let view = LauncherView()

    init() {
        panel.contentView = view
        view.results.reducesMotion = { true }
        panel.makeFirstResponder(view.field)
    }

    @Test func eventRowsShowTheTimeCalendarColourAndHowToJoin() throws {
        var standUp = event("Stand-up", "Google Meet · ended", at: "9:30 AM", meeting: true)
        standUp.isDimmed = true
        let review = event(
            "Design review", "Zoom · in 2 h 12 min · Hana, Mei", at: "2:30 PM", meeting: true,
            keys: ["⌘", "J"])
        let oneOnOne = event("1:1 with Mei", "Room 4B", at: "4:00 PM")
        view.show([.init(title: "Today · Wed 30 Sep", items: [standUp, review, oneOnOne])])
        view.results.layoutSubtreeIfNeeded()

        let table = view.results.table
        #expect(table.rect(ofRow: 1).height == ResultList.eventHeight + ResultList.rowGap)
        let ended = try cell(at: 1)
        #expect(ended.time.stringValue == "9:30 AM")
        #expect(ended.bar.fillColor == .systemGreen)
        #expect(!ended.video.isHidden)
        #expect(ended.alphaValue < 1)
        let next = try cell(at: 2)
        #expect(next.subtitle.stringValue == "Zoom · in 2 h 12 min · Hana, Mei")
        #expect(next.video.isHidden)
        #expect(!next.shortcut.isHidden)
        #expect(next.alphaValue == 1)
        let room = try cell(at: 3)
        #expect(room.video.isHidden)
        #expect(room.shortcut.isHidden)
        #expect(room.accessibilityLabel() == "4:00 PM, 1:1 with Mei, Room 4B")
    }

    @Test func aPreferredRowIsSelectedUnlessTheSelectionIsKept() {
        let ended = event("Stand-up", "ended", at: "9:30 AM")
        var review = event("Design review", "", at: "2:30 PM")
        review.prefersSelection = true
        let sections: [ResultList.Section] = [.init(title: "Today", items: [ended, review])]
        view.show(sections)
        #expect(view.results.selectedItem == review)

        view.results.selectPrevious()
        view.results.update(sections, keepingSelectionOf: ended.id)
        #expect(view.results.selectedItem == ended)
    }

    @Test func aPreferredRowBelowTheFoldIsScrolledIntoView() {
        var ended = (0..<12).map { event("Ended \($0)", "ended", at: "9:00 AM") }
        for index in ended.indices {
            ended[index].isDimmed = true
        }
        var next = event("Design review", "", at: "2:30 PM")
        next.prefersSelection = true
        view.show([.init(title: "Today", items: ended + [next])])
        view.results.layoutSubtreeIfNeeded()

        let table = view.results.table
        #expect(view.results.selectedItem == next)
        #expect(table.visibleRect.contains(table.rect(ofRow: table.selectedRow)))
    }

    @Test func commandJRunsTheRowShowingItWhicheverRowIsSelected() {
        var runs: [String] = []
        view.onRun = { runs.append("\($0.id) \($1)") }
        view.actions = { _ in [.init("Open", keys: ["↵"])] }
        let review = event("Design review", "", at: "2:30 PM", meeting: true, keys: ["⌘", "J"])
        let planning = event("Sprint planning", "", at: "10:00 AM", meeting: true)
        view.show([.init(title: "Today", items: [planning, review])])
        #expect(view.results.selectedItem == planning)

        press(kVK_ANSI_J, "j", [.command])
        #expect(runs == ["Design review 0"])
    }

    private func cell(at row: Int) throws -> EventCell {
        try #require(
            view.results.table.view(atColumn: 0, row: row, makeIfNecessary: true) as? EventCell)
    }

    private func event(
        _ title: String, _ subtitle: String, at time: String, meeting: Bool = false,
        keys: [String] = []
    ) -> ResultList.Item {
        var item = ResultList.Item(
            id: title, title: title, subtitle: subtitle, kind: "", symbol: "",
            action: meeting ? "Join Meeting" : "Open in Calendar", shortcut: keys)
        item.event = .init(time: time, colour: .systemGreen, hasMeeting: meeting)
        return item
    }

    private func press(_ keyCode: Int, _ characters: String, _ modifiers: NSEvent.ModifierFlags) {
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
        if panel.performKeyEquivalent(with: event) { return }
        panel.sendEvent(event)
    }
}
