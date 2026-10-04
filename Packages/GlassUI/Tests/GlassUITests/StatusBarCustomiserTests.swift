import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite struct StatusBarCustomiserTests {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 760, height: 476),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let view = LauncherView()
    private let pills: [StatusBar.Pill] = [
        .init(
            id: "disk", name: "Disk free", symbol: "internaldrive", value: "210",
            action: "Open Storage Settings", unit: "GB"),
        .init(
            id: "thermal", name: "Thermal state", symbol: "thermometer.medium", value: "Nominal",
            action: "Open Activity Monitor"),
        .init(
            id: "wifi", name: "Wi-Fi", symbol: "wifi", value: "Studio", action: "Wi-Fi Settings",
            shownByDefault: false),
    ]

    private var customiser: StatusBarCustomiser? {
        view.customiser?.isVisible == true ? view.customiser : nil
    }

    private var shownIDs: [String] {
        view.statusBar.pills.map(\.id)
    }

    init() {
        panel.contentView = view
        view.pills = pills
        view.onQuery = { [view] _ in view.show(view.results.sections) }
        panel.makeFirstResponder(view.field)
    }

    @Test func thePlusPillOpensAndClosesThePopoverAboveTheBar() throws {
        #expect(shownIDs == ["disk", "thermal"])
        #expect(view.statusBar.customise.accessibilityPerformPress())
        let open = try #require(customiser)
        #expect(view.statusBar.customise.isOpen)
        #expect(view.statusBar.customise.isAccessibilityExpanded())
        view.layoutSubtreeIfNeeded()
        #expect(open.glass.frame == NSRect(x: 10, y: 62, width: 380, height: 340))
        let done = open.done.convert(open.done.bounds, to: open.glass)
        #expect(
            done
                == NSRect(x: 380 - 10 - done.width, y: 340 - 27 - 14, width: done.width, height: 28)
        )
        let list = try #require(open.table.enclosingScrollView)
        #expect(list.convert(list.bounds, to: open.glass).height >= 340 - 54 - 40 - 2)
        #expect(view.statusBar.documentView?.subviews.last === view.statusBar.customise)
        #expect(open.count.stringValue == "2 of 3 shown")
        #expect(rowNames(in: open) == ["Showing", "Disk free", "Thermal state", "More", "Wi-Fi"])
        let first = try #require(row(1, in: open))
        first.layoutSubtreeIfNeeded()
        #expect(first.reading.stringValue == "210 GB")
        #expect(first.frame.width.rounded() == 368)
        #expect(first.toggle.frame.maxX.rounded() == 360)
        #expect(view.statusBar.customise.accessibilityPerformPress())
        #expect(customiser == nil)
        #expect(!view.statusBar.customise.isOpen)
    }

    @Test func switchesMovePillsBetweenShowingAndMoreAndSaveTheLayout() throws {
        var saved: [StatusBarLayout] = []
        view.onStatusLayout = { saved.append($0) }
        view.statusBar.customise.onPress?()
        let open = try #require(customiser)
        try #require(row(4, in: open)).toggle.performClick(nil)
        #expect(shownIDs == ["disk", "thermal", "wifi"])
        #expect(open.count.stringValue == "3 of 3 shown")
        try #require(row(1, in: open)).toggle.performClick(nil)
        #expect(shownIDs == ["thermal", "wifi"])
        #expect(rowNames(in: open) == ["Showing", "Thermal state", "Wi-Fi", "More", "Disk free"])
        #expect(row(4, in: open)?.toggle.state == .off)
        #expect(saved.count == 2)
        #expect(saved.last.map { $0.arrange(pills).map(\.id) } == ["thermal", "wifi"])
    }

    @Test func onlyShownPillsCanBeDraggedAndOnlyWithinShowing() throws {
        view.statusBar.customise.onPress?()
        let open = try #require(customiser)
        #expect(open.tableView(open.table, pasteboardWriterForRow: 0) == nil)
        #expect(open.tableView(open.table, pasteboardWriterForRow: 2) != nil)
        #expect(open.tableView(open.table, pasteboardWriterForRow: 4) == nil)
        open.onMove?("thermal", "disk")
        #expect(shownIDs == ["thermal", "disk"])
        #expect(rowNames(in: open) == ["Showing", "Thermal state", "Disk free", "More", "Wi-Fi"])
    }

    @Test func resetToDefaultRestoresTheCanvasOrder() throws {
        var saved: [StatusBarLayout] = []
        view.onStatusLayout = { saved.append($0) }
        view.statusBar.customise.onPress?()
        let open = try #require(customiser)
        open.onMove?("thermal", "disk")
        try #require(row(4, in: open)).toggle.performClick(nil)
        open.reset.performClick(nil)
        #expect(shownIDs == ["disk", "thermal"])
        #expect(saved.last == StatusBarLayout())
        #expect(open.count.stringValue == "2 of 3 shown")
    }

    @Test func escapeDoneTypingAndAClickOutsideCloseThePopover() throws {
        var cancels = 0
        view.onCancel = { cancels += 1 }
        view.statusBar.customise.onPress?()
        press(kVK_Escape, "\u{1B}")
        #expect(customiser == nil)
        #expect(cancels == 0)
        view.statusBar.customise.onPress?()
        try #require(customiser).done.performClick(nil)
        #expect(customiser == nil)
        view.statusBar.customise.onPress?()
        press(kVK_ANSI_A, "a")
        #expect(customiser == nil)
        view.replaceQuery(with: "")
        view.statusBar.customise.onPress?()
        view.layoutSubtreeIfNeeded()
        let inside = try #require(customiser).glass.frame
        _ = view.handle(try click(at: NSPoint(x: inside.midX, y: inside.midY)))
        #expect(customiser != nil)
        _ = view.handle(try click(at: NSPoint(x: 600, y: 300)))
        #expect(customiser == nil)
    }

    @Test func thePlusPillStaysWhenEveryPillIsOff() throws {
        view.statusBar.customise.onPress?()
        let open = try #require(customiser)
        try #require(row(1, in: open)).toggle.performClick(nil)
        try #require(row(1, in: open)).toggle.performClick(nil)
        #expect(shownIDs.isEmpty)
        #expect(!view.statusBar.isHidden)
        #expect(open.count.stringValue == "0 of 3 shown")
        press(kVK_DownArrow, "\u{F701}")
        #expect(view.selectedPill == nil)
    }

    private func row(_ index: Int, in customiser: StatusBarCustomiser) -> CustomiserRow? {
        customiser.table.view(atColumn: 0, row: index, makeIfNecessary: true) as? CustomiserRow
    }

    private func rowNames(in customiser: StatusBarCustomiser) -> [String] {
        (0..<customiser.table.numberOfRows).map { index in
            let cell = customiser.table.view(atColumn: 0, row: index, makeIfNecessary: true)
            let label = (cell as? CustomiserRow)?.name ?? cell?.subviews.first as? NSTextField
            return label?.stringValue ?? ""
        }
    }

    private func click(at point: NSPoint) throws -> NSEvent {
        try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown, location: view.convert(point, to: nil), modifierFlags: [],
                timestamp: 0, windowNumber: panel.windowNumber, context: nil, eventNumber: 0,
                clickCount: 1, pressure: 1))
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
