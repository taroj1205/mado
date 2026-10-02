import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite struct StatusBarTests {
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
    ]

    init() {
        panel.contentView = view
        view.results.sections = [
            .init(title: "Commands", items: ["Safari", "Notes", "Sleep"].map(item))
        ]
        view.pills = pills
        panel.makeFirstResponder(view.field)
    }

    @Test func theBarReplacesTheContextPillOnlyOnAnEmptyRootQuery() {
        view.context = "Colour"
        #expect(!view.statusBar.isHidden)
        #expect(view.contextPill.isHidden)
        press(kVK_Space, " ")
        #expect(!view.statusBar.isHidden)
        press(kVK_ANSI_A, "a")
        #expect(view.statusBar.isHidden)
        #expect(view.contextPill.text == "Colour")
        view.replaceQuery(with: "")
        #expect(!view.statusBar.isHidden)
        view.enter(placeholder: "Filter")
        #expect(view.statusBar.isHidden)
        view.leave()
        view.pills = []
        #expect(view.statusBar.isHidden)
        #expect(!view.contextPill.isHidden)
    }

    @Test func thePillsSitAtTheBottomLeftBesideTheActionCapsule() throws {
        view.layoutSubtreeIfNeeded()
        let first = try #require(view.statusBar.views.first)
        let frame = view.convert(first.bounds, from: first)
        #expect(view.statusBar.frame.minX == 10)
        #expect(frame.minX == 12)
        #expect(frame.height == 36)
        #expect(abs(frame.midY - view.actionCapsule.frame.midY) < 1)
        #expect(view.statusBar.frame.maxX <= view.actionCapsule.frame.minX - 10)
        #expect(first.text == "210 GB")
        #expect(first.accessibilityLabel() == "Disk free: 210 GB")
    }

    @Test func downFromTheLastRowEntersThePillsAndArrowsMoveAlongThem() {
        for _ in 0..<3 {
            press(kVK_DownArrow, "\u{F701}")
        }
        #expect(view.selectedPill == 0)
        #expect(view.statusBar.views.map(\.selected) == [true, false])
        #expect(view.results.hidesSelection)
        #expect(view.actionLabel.stringValue == "Open Storage Settings")
        press(kVK_RightArrow, "\u{F703}")
        press(kVK_RightArrow, "\u{F703}")
        #expect(view.selectedPill == 1)
        #expect(view.actionLabel.stringValue == "Open Activity Monitor")
        press(kVK_LeftArrow, "\u{F702}")
        press(kVK_LeftArrow, "\u{F702}")
        #expect(view.selectedPill == 0)
        press(kVK_UpArrow, "\u{F700}")
        #expect(view.selectedPill == nil)
        #expect(!view.results.hidesSelection)
        #expect(view.results.selectedItem?.id == "Sleep")
        #expect(view.actionLabel.stringValue == "Run Command")
    }

    @Test func returnRunsThePillAndEscapeOnlyLeavesIt() {
        var ran: [String] = []
        var cancels = 0
        view.onPill = { ran.append($0.id) }
        view.onRun = { item, _ in ran.append(item.id) }
        view.onCancel = { cancels += 1 }
        view.results.sections = []
        press(kVK_DownArrow, "\u{F701}")
        press(kVK_RightArrow, "\u{F703}")
        press(kVK_Return, "\r")
        #expect(ran == ["thermal"])
        press(kVK_Escape, "\u{1B}")
        #expect(view.selectedPill == nil)
        #expect(cancels == 0)
        press(kVK_Escape, "\u{1B}")
        #expect(cancels == 1)
    }

    @Test func commandKeysLeaveThePillsBeforeActingOnTheRow() {
        for _ in 0..<3 {
            press(kVK_DownArrow, "\u{F701}")
        }
        press(kVK_ANSI_K, "k", [.command])
        #expect(view.selectedPill == nil)
        #expect(!view.results.hidesSelection)
        #expect(view.choosingAction)
        view.closeActions()
    }

    @Test func typingLeavesThePillsAndHidesTheBar() {
        view.pressPill(0)
        #expect(view.selectedPill == 0)
        press(kVK_ANSI_A, "a")
        #expect(view.selectedPill == nil)
        #expect(view.statusBar.isHidden)
    }

    @Test func clickingAPillSelectsItAndClickingAgainLetsGo() throws {
        let pill = try #require(view.statusBar.views.last)
        #expect(pill.accessibilityPerformPress())
        #expect(view.selectedPill == 1)
        #expect(pill.icon.contentTintColor == .controlAccentColor)
        #expect(pill.accessibilityPerformPress())
        #expect(view.selectedPill == nil)
        #expect(pill.icon.contentTintColor == .secondaryLabelColor)
        #expect(view.contextPill.accessibilityPerformPress() == false)
    }

    @Test func withoutPillsDownStopsAtTheLastRow() {
        view.pills = []
        for _ in 0..<5 {
            press(kVK_DownArrow, "\u{F701}")
        }
        #expect(view.selectedPill == nil)
        #expect(view.results.selectedItem?.id == "Sleep")
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

    private func item(_ title: String) -> ResultList.Item {
        .init(
            id: title, title: title, subtitle: "", kind: "Command", symbol: "star",
            action: "Run Command")
    }
}
