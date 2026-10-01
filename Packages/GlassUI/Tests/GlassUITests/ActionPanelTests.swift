import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite(.serialized) struct ActionPanelTests {
    private let panel = GlassPanel(
        kind: .panel, contentRect: NSRect(x: 100, y: 100, width: 760, height: 476),
        shape: .rounded(28))
    private let view = LauncherView()

    init() {
        panel.glass.contentView = view
        panel.onEvent = { [view] in view.handle($0) }
        view.results.sections = [
            .init(title: "Results", items: [item("Terminal"), item("Notes")])
        ]
        view.actionTitles = { _ in ["Open Application", "Show in Finder", "Copy Path"] }
        panel.makeFirstResponder(view.field)
    }

    @Test func commandKOpensTheSelectedRowsActionsAsAChildWindowAboveTheCapsule() throws {
        defer { view.closeActions() }
        press(kVK_DownArrow, "\u{F701}", in: panel)
        press(kVK_ANSI_K, "k", in: panel, [.command])
        let menu = try #require(view.actionPanel)
        #expect(view.choosingAction)
        #expect(menu.panel.parent === panel)
        #expect(menu.header.stringValue == "Notes")
        #expect(
            menu.rows.map(\.label.stringValue) == [
                "Open Application", "Show in Finder", "Copy Path",
            ])
        #expect(menu.rows.map { $0.keycaps.map(\.name.stringValue) } == [["↵"], ["⌘", "↵"], []])
        #expect(menu.rows.map(\.isSelected) == [true, false, false])
        menu.panel.layoutIfNeeded()
        #expect(!menu.rows.flatMap(\.keycaps).map(\.hasAmbiguousLayout).contains(true))
        #expect(menu.rows.flatMap(\.keycaps).allSatisfy { $0.frame.width < 30 })
        #expect(menu.panel.firstResponder === menu.field.currentEditor())
        let capsule = panel.convertToScreen(
            view.actionCapsule.convert(view.actionCapsule.bounds, to: nil))
        #expect(menu.panel.frame.maxX == capsule.maxX)
        #expect(menu.panel.frame.minY == capsule.maxY + 10)
        #expect(menu.panel.frame.width == 316)
        #expect(view.actionsToggle.fillColor == ResultRowView.fill)
    }

    @Test func typingFiltersAndReturnRunsTheChosenAction() throws {
        var runs: [String] = []
        view.onRun = { runs.append("\($0.id) \($1)") }
        press(kVK_ANSI_K, "k", in: panel, [.command])
        let menu = try #require(view.actionPanel)
        let height = menu.panel.frame.height
        type("path", in: menu)
        #expect(menu.rows.map(\.label.stringValue) == ["Copy Path"])
        #expect(menu.panel.frame.height < height)
        type("", in: menu)
        press(kVK_DownArrow, "\u{F701}", in: menu.panel)
        press(kVK_DownArrow, "\u{F701}", in: menu.panel)
        press(kVK_DownArrow, "\u{F701}", in: menu.panel)
        #expect(menu.rows.map(\.isSelected) == [false, false, true])
        press(kVK_Return, "\r", in: menu.panel)
        #expect(runs == ["Terminal 2"])
        #expect(!view.choosingAction)
        #expect(view.actionsToggle.fillColor == .clear)
    }

    @Test func commandReturnInThePanelRunsTheSecondaryAction() throws {
        var runs: [String] = []
        view.onRun = { runs.append("\($0.id) \($1)") }
        press(kVK_ANSI_K, "k", in: panel, [.command])
        let menu = try #require(view.actionPanel)
        type("copy", in: menu)
        press(kVK_Return, "\r", in: menu.panel, [.command])
        #expect(runs == ["Terminal 1"])
    }

    @Test func clickingARowRunsIt() throws {
        var runs: [String] = []
        view.onRun = { runs.append("\($0.id) \($1)") }
        press(kVK_ANSI_K, "k", in: panel, [.command])
        let menu = try #require(view.actionPanel)
        #expect(menu.rows[1].accessibilityPerformPress())
        #expect(runs == ["Terminal 1"])
        #expect(!view.choosingAction)
    }

    @Test func escapeAndCommandKCloseThePanelButKeepTheLauncher() throws {
        var cancels = 0
        view.onCancel = { cancels += 1 }
        press(kVK_ANSI_K, "k", in: panel, [.command])
        let menu = try #require(view.actionPanel)
        press(kVK_Escape, "\u{1B}", in: menu.panel)
        #expect(!view.choosingAction)
        #expect(menu.panel.parent == nil)
        press(kVK_ANSI_K, "k", in: panel, [.command])
        #expect(view.choosingAction)
        press(kVK_ANSI_K, "k", in: menu.panel, [.command])
        #expect(!view.choosingAction)
        #expect(cancels == 0)
    }

    @Test func clickingTheLauncherClosesThePanel() throws {
        press(kVK_ANSI_K, "k", in: panel, [.command])
        let click = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown, location: CGPoint(x: 380, y: 200), modifierFlags: [],
                timestamp: 0, windowNumber: panel.windowNumber, context: nil, eventNumber: 0,
                clickCount: 1, pressure: 1))
        #expect(!view.handle(click))
        #expect(!view.choosingAction)
    }

    @Test func commandKDoesNothingWithoutASelection() {
        view.results.sections = []
        press(kVK_ANSI_K, "k", in: panel, [.command])
        #expect(!view.choosingAction)
    }

    @Test func losingFocusToAnotherAppClosesThePanelAndReportsIt() throws {
        var lost = 0
        view.onFocusLost = { lost += 1 }
        press(kVK_ANSI_K, "k", in: panel, [.command])
        let menu = try #require(view.actionPanel)
        menu.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification))
        #expect(!view.choosingAction)
        #expect(lost == 1)
        menu.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification))
        #expect(lost == 1)
    }

    private func type(_ text: String, in menu: ActionPanel) {
        menu.field.stringValue = text
        menu.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
    }

    private func press(
        _ keyCode: Int, _ characters: String, in window: NSWindow,
        _ modifiers: NSEvent.ModifierFlags = []
    ) {
        guard
            let event = NSEvent.keyEvent(
                with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
                windowNumber: window.windowNumber, context: nil, characters: characters,
                charactersIgnoringModifiers: characters, isARepeat: false,
                keyCode: UInt16(keyCode))
        else {
            Issue.record("Could not make a key event for \(keyCode)")
            return
        }
        if modifiers.contains(.command), window.performKeyEquivalent(with: event) { return }
        window.sendEvent(event)
    }

    private func item(_ title: String) -> ResultList.Item {
        .init(
            id: title, title: title, subtitle: "", kind: "Application", symbol: "star",
            action: "Open Application")
    }
}
