import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetGridTests {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 760, height: 548),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let view = LauncherView()
    private let widgets: [WidgetGrid.Widget] = [
        .init(
            id: "clock", value: "9:41", detail: "Wed 30 Sep", action: "Open Clock",
            spoken: "Time: 9:41 AM, Wednesday 30 September"),
        .init(
            id: "weather", value: "15°", detail: "Partly cloudy", action: "Open Weather",
            spoken: "Weather: 15 degrees, partly cloudy"),
    ]

    init() {
        panel.contentView = view
        view.results.sections = [
            .init(title: "Commands", items: ["Safari", "Notes", "Sleep"].map(item))
        ]
        view.widgets = widgets
        view.pills = [
            .init(
                id: "uptime", name: "Uptime", symbol: "clock", value: "17h",
                action: "Show System Report")
        ]
        panel.makeFirstResponder(view.field)
    }

    @Test func theGridShowsOnlyOnAnEmptyRootQueryAndTheListTakesItsPlace() {
        view.layoutSubtreeIfNeeded()
        let listTop = view.results.frame.maxY
        #expect(!view.widgetGrid.isHidden)
        #expect(abs(view.widgetGrid.frame.height - (12 + 78 + 4)) < 0.01)
        press(kVK_ANSI_A, "a")
        view.layoutSubtreeIfNeeded()
        #expect(view.widgetGrid.isHidden)
        #expect(view.widgetGrid.frame.height == 0)
        #expect(abs(view.results.frame.maxY - listTop - 94) < 0.01)
        view.replaceQuery(with: " ")
        #expect(!view.widgetGrid.isHidden)
        view.enter(placeholder: "Filter")
        #expect(view.widgetGrid.isHidden)
        view.leave()
        view.widgets = []
        #expect(view.widgetGrid.isHidden)
    }

    @Test func tilesFillSixColumnsBelowTheSearchBar() throws {
        view.layoutSubtreeIfNeeded()
        let first = try #require(view.widgetGrid.tiles.first)
        let second = try #require(view.widgetGrid.tiles.last)
        let frame = view.convert(first.bounds, from: first)
        #expect(frame.minX == 14)
        #expect(abs(frame.width - (732 - 5 * 8) / 6) < 0.01)
        #expect(frame.height == 78)
        #expect(abs(view.bounds.height - frame.maxY - (60 + 1 + 12)) < 1)
        #expect(abs(view.convert(second.bounds, from: second).minX - frame.maxX - 8) < 0.01)
        #expect(first.value.stringValue == "9:41")
        #expect(first.detail.stringValue == "Wed 30 Sep")
        #expect(first.accessibilityLabel() == "Time: 9:41 AM, Wednesday 30 September")
    }

    @Test func upFromTheFirstRowEntersTheWidgetsAndDownComesBack() {
        press(kVK_UpArrow, "\u{F700}")
        #expect(view.selectedWidget == 0)
        #expect(view.widgetGrid.tiles.map(\.selected) == [true, false])
        #expect(view.results.hidesSelection)
        #expect(view.actionLabel.stringValue == "Open Clock")
        press(kVK_RightArrow, "\u{F703}")
        press(kVK_RightArrow, "\u{F703}")
        #expect(view.selectedWidget == 1)
        #expect(view.actionLabel.stringValue == "Open Weather")
        press(kVK_UpArrow, "\u{F700}")
        #expect(view.selectedWidget == 1)
        press(kVK_LeftArrow, "\u{F702}")
        press(kVK_LeftArrow, "\u{F702}")
        #expect(view.selectedWidget == 0)
        press(kVK_DownArrow, "\u{F701}")
        #expect(view.selectedWidget == nil)
        #expect(!view.results.hidesSelection)
        #expect(view.results.selectedItem?.id == "Safari")
        #expect(view.actionLabel.stringValue == "Run Command")
    }

    @Test func downReturnsToTheFirstRowEvenAfterAClickFromLowerDown() throws {
        press(kVK_DownArrow, "\u{F701}")
        press(kVK_DownArrow, "\u{F701}")
        #expect(try #require(view.widgetGrid.tiles.last).accessibilityPerformPress())
        #expect(view.selectedWidget == 1)
        press(kVK_DownArrow, "\u{F701}")
        #expect(view.results.selectedItem?.id == "Safari")
    }

    @Test func upInsideTheListOnlyMovesTheRow() {
        press(kVK_DownArrow, "\u{F701}")
        press(kVK_UpArrow, "\u{F700}")
        #expect(view.selectedWidget == nil)
        #expect(view.results.selectedItem?.id == "Safari")
    }

    @Test func returnRunsTheWidgetAndEscapeOnlyLeavesIt() {
        var ran: [String] = []
        var cancels = 0
        view.onWidget = { ran.append($0.id) }
        view.onRun = { item, _ in ran.append(item.id) }
        view.onCancel = { cancels += 1 }
        press(kVK_UpArrow, "\u{F700}")
        press(kVK_RightArrow, "\u{F703}")
        press(kVK_Return, "\r")
        #expect(ran == ["weather"])
        press(kVK_Escape, "\u{1B}")
        #expect(view.selectedWidget == nil)
        #expect(view.results.selectedItem?.id == "Safari")
        #expect(cancels == 0)
        press(kVK_Escape, "\u{1B}")
        #expect(cancels == 1)
    }

    @Test func commandKeysAndTypingLeaveTheWidgets() {
        press(kVK_UpArrow, "\u{F700}")
        press(kVK_ANSI_K, "k", [.command])
        #expect(view.selectedWidget == nil)
        #expect(view.choosingAction)
        view.closeActions()
        view.pressWidget(0)
        press(kVK_ANSI_A, "a")
        #expect(view.selectedWidget == nil)
        #expect(view.widgetGrid.isHidden)
    }

    @Test func aWidgetAndAPillAreNeverSelectedTogether() {
        view.pressWidget(1)
        view.pressPill(0)
        #expect(view.selectedWidget == nil)
        #expect(view.widgetGrid.tiles.allSatisfy { !$0.selected })
        #expect(view.results.hidesSelection)
        view.pressWidget(1)
        #expect(view.selectedPill == nil)
        #expect(view.results.hidesSelection)
        #expect(view.actionLabel.stringValue == "Open Weather")
    }

    @Test func clickingAWidgetSelectsAndRunsIt() throws {
        var ran: [String] = []
        view.onWidget = { ran.append($0.id) }
        #expect(try #require(view.widgetGrid.tiles.last).accessibilityPerformPress())
        #expect(view.selectedWidget == 1)
        #expect(view.results.hidesSelection)
        #expect(ran == ["weather"])
    }

    @Test func refreshedValuesKeepTheSelectedTile() throws {
        view.pressWidget(1)
        let tile = try #require(view.widgetGrid.tiles.first)
        view.widgets = [
            .init(
                id: "clock", value: "9:42", detail: "Wed 30 Sep", action: "Open Clock",
                spoken: "Time: 9:42 AM, Wednesday 30 September"),
            widgets[1],
        ]
        #expect(view.widgetGrid.tiles.first === tile)
        #expect(tile.value.stringValue == "9:42")
        #expect(view.selectedWidget == 1)
        #expect(view.widgetGrid.tiles.last?.selected == true)
        view.widgets = [widgets[0]]
        #expect(view.selectedWidget == nil)
        #expect(!view.results.hidesSelection)
    }

    @Test func aMeterWidgetDrawsOneBarPerMeterAndUpdatesInPlace() throws {
        let system = WidgetGrid.Widget(
            id: "system",
            meters: [
                .init(name: "CPU", value: "23%", level: 0.23),
                .init(name: "RAM", value: "–", level: 0),
            ],
            action: "Open Activity Monitor", spoken: "System: CPU 23%, memory –")
        view.widgets = [widgets[0], system]
        view.layoutSubtreeIfNeeded()
        let tile = try #require(view.widgetGrid.tiles.last)
        let meters = tile.meters.arrangedSubviews.compactMap { $0 as? WidgetMeter }
        #expect(meters.map(\.name.stringValue) == ["CPU", "RAM"])
        #expect(meters.map(\.value.stringValue) == ["23%", "–"])
        #expect(meters.map(\.level) == [0.23, 0])
        #expect(tile.value.isHidden && tile.detail.isHidden)
        #expect(tile.accessibilityLabel() == "System: CPU 23%, memory –")
        let first = try #require(meters.first)
        #expect(abs(first.frame.width - (tile.bounds.width - 24)) < 1)
        #expect(abs(tile.meters.frame.midY - tile.bounds.midY) < 0.5)
        view.pressWidget(1)
        view.widgets = [
            widgets[0],
            .init(
                id: "system",
                meters: [
                    .init(name: "CPU", value: "140%", level: 1.4),
                    .init(name: "RAM", value: "61%", level: 0.61),
                ],
                action: "Open Activity Monitor", spoken: "System: CPU 140%, memory 61%"),
        ]
        #expect(view.widgetGrid.tiles.last === tile)
        #expect(tile.meters.arrangedSubviews.first === first)
        #expect(meters.map(\.level) == [1, 0.61])
        #expect(view.selectedWidget == 1)
        #expect(view.actionLabel.stringValue == "Open Activity Monitor")
        view.widgets = [widgets[0], widgets[0]]
        #expect(tile.meters.arrangedSubviews.isEmpty)
        #expect(!tile.value.isHidden && !tile.detail.isHidden)
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
