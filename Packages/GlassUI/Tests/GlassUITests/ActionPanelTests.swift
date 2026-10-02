import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite(.serialized) final class ActionPanelTests {
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
        view.actions = { _ in
            [
                .init("Open Application", keys: ["↵"]), .init("Show in Finder", keys: ["⌘", "↵"]),
                .init("Copy Path"),
            ]
        }
        panel.makeFirstResponder(view.field)
    }

    @Test func commandKOpensTheSelectedRowsActionsAsGlassAboveTheCapsule() throws {
        defer { view.closeActions() }
        press(kVK_DownArrow, "\u{F701}", in: panel)
        press(kVK_ANSI_K, "k", in: panel, [.command])
        let menu = try #require(view.actionPanel)
        #expect(view.choosingAction)
        let host = unsafe menu.glass.superview
        #expect(host === view)
        #expect(menu.header.stringValue == "Notes")
        #expect(
            menu.rows.map(\.label.stringValue) == [
                "Open Application", "Show in Finder", "Copy Path",
            ])
        #expect(menu.rows.map { $0.keycaps.map(\.name.stringValue) } == [["↵"], ["⌘", "↵"], []])
        #expect(menu.rows.map(\.isSelected) == [true, false, false])
        view.layoutSubtreeIfNeeded()
        #expect(!menu.rows.flatMap(\.keycaps).map(\.hasAmbiguousLayout).contains(true))
        #expect(menu.rows.flatMap(\.keycaps).allSatisfy { $0.frame.width < 30 })
        #expect(panel.firstResponder === menu.field.currentEditor())
        #expect(menu.glass.frame.maxX == view.actionCapsule.frame.maxX)
        #expect(menu.glass.frame.minY == view.actionCapsule.frame.maxY + 10)
        #expect(menu.glass.frame.width == 316)
        let border = try #require(menu.glass.contentView?.subviews.last as? GlassBorder)
        #expect(border.frame == menu.glass.bounds)
        #expect(border.rim.frame == border.bounds.insetBy(dx: 0.5, dy: 0.5))
        #expect(border.hitTest(NSPoint(x: border.bounds.midX, y: border.bounds.midY)) == nil)
        #expect(view.actionsToggle.fillColor == ResultRowView.fill)
    }

    @Test func glassInsideTheLauncherHasNoSheen() throws {
        defer { view.closeActions() }
        press(kVK_ANSI_K, "k", in: panel, [.command])
        let menu = try #require(view.actionPanel)
        #expect(menu.glass.sheen.isHidden)
        #expect(view.actionCapsule.sheen.isHidden)
        #expect(view.contextCapsule.sheen.isHidden)
        #expect(!panel.glass.sheen.isHidden)
    }

    @Test func typingFiltersAndReturnRunsTheChosenAction() throws {
        var runs: [String] = []
        view.onRun = { runs.append("\($0.id) \($1)") }
        press(kVK_ANSI_K, "k", in: panel, [.command])
        let menu = try #require(view.actionPanel)
        view.layoutSubtreeIfNeeded()
        let height = menu.glass.frame.height
        type("path", in: menu)
        view.layoutSubtreeIfNeeded()
        #expect(menu.rows.map(\.label.stringValue) == ["Copy Path"])
        #expect(menu.glass.frame.height < height)
        type("", in: menu)
        press(kVK_DownArrow, "\u{F701}", in: panel)
        press(kVK_DownArrow, "\u{F701}", in: panel)
        press(kVK_DownArrow, "\u{F701}", in: panel)
        #expect(menu.rows.map(\.isSelected) == [false, false, true])
        press(kVK_Return, "\r", in: panel)
        #expect(runs == ["Terminal 2"])
        #expect(!view.choosingAction)
        #expect(view.actionsToggle.fillColor == .clear)
    }

    @Test func aFilterWithNoMatchesSaysSoAndReturnDoesNothing() throws {
        defer { view.closeActions() }
        var runs: [String] = []
        view.onRun = { runs.append("\($0.id) \($1)") }
        press(kVK_ANSI_K, "k", in: panel, [.command])
        let menu = try #require(view.actionPanel)
        #expect(!menu.empty.isDescendant(of: menu.glass))
        type("zzz", in: menu)
        #expect(menu.rows.isEmpty)
        #expect(menu.empty.isDescendant(of: menu.glass))
        #expect(menu.empty.label.stringValue == "No matching actions")
        press(kVK_Return, "\r", in: panel)
        #expect(runs.isEmpty)
        #expect(view.choosingAction)
        type("", in: menu)
        #expect(!menu.empty.isDescendant(of: menu.glass))
        #expect(menu.rows.count == 3)
    }

    @Test func commandReturnInThePanelRunsTheSecondaryAction() throws {
        var runs: [String] = []
        view.onRun = { runs.append("\($0.id) \($1)") }
        press(kVK_ANSI_K, "k", in: panel, [.command])
        let menu = try #require(view.actionPanel)
        type("copy", in: menu)
        press(kVK_Return, "\r", in: panel, [.command])
        #expect(runs == ["Terminal 1"])
    }

    @Test func commandReturnOnlyRunsTheActionMarkedSecondary() throws {
        var runs: [String] = []
        view.onRun = { runs.append("\($0.id) \($1)") }
        view.actions = { _ in [.init("Open", keys: ["↵"]), .init("Add to Favourites")] }
        press(kVK_Return, "\r", in: panel, [.command])
        press(kVK_ANSI_K, "k", in: panel, [.command])
        let menu = try #require(view.actionPanel)
        #expect(menu.rows.map { $0.keycaps.map(\.name.stringValue) } == [["↵"], []])
        press(kVK_Return, "\r", in: panel, [.command])
        #expect(runs.isEmpty)
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
        view.field.stringValue = "term"
        press(kVK_ANSI_K, "k", in: panel, [.command])
        let menu = try #require(view.actionPanel)
        press(kVK_Escape, "\u{1B}", in: panel)
        #expect(!view.choosingAction)
        #expect(!menu.isVisible)
        let editor = try #require(view.field.currentEditor())
        #expect(panel.firstResponder === editor)
        #expect(editor.selectedRange == NSRange(location: 4, length: 0))
        press(kVK_ANSI_K, "k", in: panel, [.command])
        #expect(view.choosingAction)
        press(kVK_ANSI_K, "k", in: panel, [.command])
        #expect(!view.choosingAction)
        #expect(cancels == 0)
    }

    @Test func clickingThePanelKeepsItOpenAndClickingTheLauncherClosesIt() throws {
        press(kVK_ANSI_K, "k", in: panel, [.command])
        let menu = try #require(view.actionPanel)
        view.layoutSubtreeIfNeeded()
        let inside = menu.glass.convert(menu.glass.bounds, to: nil)
        let press = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown, location: CGPoint(x: inside.midX, y: inside.midY),
                modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber, context: nil,
                eventNumber: 0, clickCount: 1, pressure: 1))
        #expect(!view.handle(press))
        #expect(view.choosingAction)
        let click = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown, location: CGPoint(x: 380, y: 200), modifierFlags: [],
                timestamp: 0, windowNumber: panel.windowNumber, context: nil, eventNumber: 0,
                clickCount: 1, pressure: 1))
        #expect(!view.handle(click))
        #expect(!view.choosingAction)
    }

    @Test func clickingTheActionsCapsuleTogglesThePanel() throws {
        defer { view.closeActions() }
        view.layoutSubtreeIfNeeded()
        let toggle = view.actionsToggle
        let center = toggle.convert(NSPoint(x: toggle.bounds.midX, y: toggle.bounds.midY), to: nil)
        let click = try #require(
            NSEvent.mouseEvent(
                with: .leftMouseDown, location: center, modifierFlags: [], timestamp: 0,
                windowNumber: panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1,
                pressure: 1))
        #expect(toggle.accessibilityRole() == .button)

        #expect(!view.handle(click))
        toggle.mouseDown(with: click)
        #expect(view.choosingAction)
        #expect(!view.handle(click))
        #expect(view.choosingAction)
        #expect(toggle.accessibilityPerformPress())
        #expect(!view.choosingAction)
    }

    @Test func reopeningForARowWithMoreActionsGrowsThePanel() throws {
        view.actions = { item in
            item.id == "Notes"
                ? [.init("Open Application", keys: ["↵"]), .init("Add to Favourites")]
                : [.init("One", keys: ["↵"]), .init("Two", keys: ["⌘", "↵"]), .init("Three")]
        }
        press(kVK_DownArrow, "\u{F701}", in: panel)
        press(kVK_ANSI_K, "k", in: panel, [.command])
        let menu = try #require(view.actionPanel)
        view.layoutSubtreeIfNeeded()
        let short = menu.glass.frame.height
        press(kVK_Escape, "\u{1B}", in: panel)
        press(kVK_UpArrow, "\u{F700}", in: panel)
        press(kVK_ANSI_K, "k", in: panel, [.command])
        view.layoutSubtreeIfNeeded()
        #expect(menu.rows.count == 3)
        #expect(menu.glass.frame.height > short)
        let header = menu.glass.convert(menu.header.bounds, from: menu.header)
        #expect(menu.glass.bounds.contains(header))
    }

    @Test func commandKDoesNothingWithoutASelection() {
        view.results.sections = []
        press(kVK_ANSI_K, "k", in: panel, [.command])
        #expect(!view.choosingAction)
    }

    @Test func typingInTheLauncherFiltersThePanelAndLeavesTheQuery() throws {
        view.field.stringValue = "term"
        press(kVK_ANSI_K, "k", in: panel, [.command])
        let menu = try #require(view.actionPanel)
        press(kVK_ANSI_P, "p", in: panel)
        #expect(menu.field.stringValue == "p")
        #expect(view.field.stringValue == "term")
        #expect(menu.rows.map(\.label.stringValue) == ["Open Application", "Copy Path"])
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

    isolated deinit {
        panel.makeFirstResponder(nil)
    }
}
