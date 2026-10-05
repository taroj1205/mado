import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetStateTests {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 760, height: 548),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let view = LauncherView()
    private let upNext = WidgetGrid.Widget(
        id: "next", name: "Up Next",
        content: .notice(
            title: "Up Next", headline: "Nothing else today",
            detail: "Tomorrow 10:00 · Stand-up"),
        action: "Open Calendar", spoken: "Up next: nothing else today", isWide: true)
    private let calendar = WidgetGrid.Widget(
        id: "calendar", name: "Calendar",
        content: .permission(
            title: "Calendar", request: "Allow calendar access",
            reason: "To show your next meeting"),
        action: "Allow Calendar Access", spoken: "Calendar: allow calendar access",
        isWide: true)
    private let weather = WidgetGrid.Widget(
        id: "weather", name: "Weather", content: .loading(title: "Weather"), action: "Open Weather",
        spoken: "Weather: loading")

    init() {
        panel.contentView = view
        view.results.sections = [
            .init(
                title: "Commands",
                items: [
                    .init(
                        id: "Safari", title: "Safari", subtitle: "", kind: "Command",
                        symbol: "star", action: "Run Command")
                ])
        ]
        view.widgets = [upNext, calendar, weather, small("clock"), small("system")]
        panel.makeFirstResponder(view.field)
    }

    @Test func aThirdLineFitsTheGridButNotTheStrip() throws {
        let forecast = WidgetGrid.Widget(
            id: "weather", name: "Weather", value: "11°", detail: "Partly cloudy",
            action: "Open Weather", spoken: "Weather: 11 degrees",
            span: .init(
                low: "9°", high: "15°", position: 0.33, cold: .systemTeal, warm: .systemGreen))
        view.widgets = [forecast, small("clock")]
        view.layoutSubtreeIfNeeded()
        let tile = try #require(view.widgetGrid.tiles.first)
        #expect(visible(in: tile) == [tile.value, tile.detail, tile.span])
        #expect([tile.span.low.stringValue, tile.span.high.stringValue] == ["9°", "15°"])
        #expect(tile.span.position == 0.33)
        let box = tile.convert(tile.span.bounds, from: tile.span)
        #expect(tile.bounds.insetBy(dx: 0, dy: WidgetTile.vertical - 0.5).contains(box))
        view.widgetLayout = .strip
        view.layoutSubtreeIfNeeded()
        let strip = try #require(view.widgetGrid.tiles.first)
        #expect(visible(in: strip) == [strip.value, strip.detail])
        view.widgetSpots = ["weather": .aboveLeft]
        let above = view.widgetGrid.tiles.first(where: \.floating)
        let floating = try #require(above)
        #expect(visible(in: floating) == [floating.value, floating.detail, floating.span])
    }

    @Test func wideTilesSpanTwoColumnsAndTheNextTileWrapsWhenARowIsFull() {
        view.layoutSubtreeIfNeeded()
        let frames = view.widgetGrid.tiles.map(\.frame)
        let column = (732 - 5 * 8) / 6.0
        let columns: [CGFloat] = [0, 2, 4, 5, 0]
        let spans: [CGFloat] = [2, 2, 1, 1, 1]
        for (frame, (start, span)) in zip(frames, zip(columns, spans)) {
            #expect(abs(frame.minX - 14 - start * (column + 8)) < 0.01)
            #expect(abs(frame.width - (span * column + (span - 1) * 8)) < 0.01)
        }
        #expect(frames.map(\.minY) == [12, 12, 12, 12, 98])
        #expect(abs(view.widgetGrid.frame.height - (12 + 78 + 8 + 78 + 4)) < 0.01)
    }

    @Test func theStripKeepsOnlyTheWidgetsThatFitOneRow() {
        view.widgets = [upNext, calendar, weather, small("clock"), small("system")]
        view.widgetLayout = .strip
        #expect(view.widgetGrid.tiles.count == 4)
        view.widgets = [upNext, calendar, upNext, small("clock")]
        #expect(view.widgetGrid.shown.map(\.id) == ["next", "calendar", "next"])
    }

    @Test func everyStateKeepsTheTileSize() throws {
        view.layoutSubtreeIfNeeded()
        let tile = try #require(view.widgetGrid.tiles.first)
        let frame = tile.frame
        let states: [WidgetGrid.Content] = [
            .loading(title: "Up Next"),
            .permission(title: "Up Next", request: "Allow calendar access", reason: "To show"),
            .value("Design review", detail: "2:30 – 3:00 PM · Zoom"),
            .meters([.init(name: "CPU", value: "23%", level: 0.23)]),
            upNext.content,
        ]
        for content in states {
            view.widgets = [
                .init(
                    id: "next", name: "Up Next", content: content, action: "Open Calendar",
                    spoken: "Up next",
                    isWide: true),
                calendar, weather, small("clock"), small("system"),
            ]
            view.layoutSubtreeIfNeeded()
            #expect(view.widgetGrid.tiles.first === tile)
            #expect(tile.frame == frame)
        }
    }

    @Test func theEmptyStateSaysWhatIsNextAndReturnStillRunsTheAction() throws {
        var ran: [String] = []
        view.onWidget = { ran.append($0.action) }
        view.layoutSubtreeIfNeeded()
        let tile = try #require(view.widgetGrid.tiles.first)
        #expect(visible(in: tile) == [tile.title, tile.headline, tile.detail])
        #expect(tile.title.stringValue == "UP NEXT")
        #expect(tile.headline.stringValue == "Nothing else today")
        #expect(tile.detail.stringValue == "Tomorrow 10:00 · Stand-up")
        #expect(tile.accessibilityLabel() == "Up next: nothing else today")
        press(kVK_UpArrow, "\u{F700}")
        #expect(view.actionLabel.stringValue == "Open Calendar")
        press(kVK_Return, "\r")
        #expect(ran == ["Open Calendar"])
    }

    @Test func theLoadingStateShowsTheNameAndTwoBars() throws {
        view.layoutSubtreeIfNeeded()
        let tile = view.widgetGrid.tiles[2]
        #expect(visible(in: tile) == [tile.title] + tile.skeleton)
        #expect(tile.title.stringValue == "WEATHER")
        let content = tile.bounds.width - 24
        #expect(tile.skeleton.map { ($0.frame.width / content * 10).rounded() } == [4, 7])
        #expect(tile.skeleton.map(\.frame.height) == [18, 10])
        let last = try #require(tile.skeleton.last)
        #expect(abs(tile.convert(last.bounds, from: last).minY - 10) < 0.5)
    }

    @Test func thePermissionStateAsksWithOneAllowButtonThatRunsTheWidgetAction() {
        var ran: [String] = []
        view.onWidget = { ran.append($0.id) }
        view.layoutSubtreeIfNeeded()
        let tile = view.widgetGrid.tiles[1]
        #expect(visible(in: tile) == [tile.title, tile.headline, tile.reason, tile.allow])
        #expect(tile.headline.stringValue == "Allow calendar access")
        #expect(tile.reason.stringValue == "To show your next meeting")
        #expect(tile.allow.label.stringValue == "Allow")
        let allow = tile.convert(tile.allow.bounds, from: tile.allow)
        #expect(tile.hitTest(NSPoint(x: tile.frame.minX + allow.midX, y: tile.frame.midY)) === tile)
        view.pressWidget(1)
        #expect(view.actionLabel.stringValue == "Allow Calendar Access")
        #expect(ran == ["calendar"])
    }

    @Test func theAllowButtonSitsAtTheRightOfTheReason() {
        view.layoutSubtreeIfNeeded()
        let tile = view.widgetGrid.tiles[1]
        let allow = tile.convert(tile.allow.bounds, from: tile.allow)
        #expect(abs(tile.bounds.maxX - allow.maxX - 12) <= 1)
        #expect(allow.height == 24)
    }

    @Test func theReasonFitsBesideTheAllowButtonInAWideTile() {
        view.layoutSubtreeIfNeeded()
        let tile = view.widgetGrid.tiles[1]
        let shown = tile.reason.alignmentRect(forFrame: tile.reason.frame)
        let reason = tile.convert(tile.reason.bounds, from: tile.reason)
        let allow = tile.convert(tile.allow.bounds, from: tile.allow)
        #expect(tile.reason.intrinsicContentSize.width <= shown.width)
        #expect(reason.maxX - tile.reason.alignmentRectInsets.right <= allow.minX)
    }

    @Test func aReusedTileHidesWhatTheLastStateShowed() {
        view.layoutSubtreeIfNeeded()
        let tile = view.widgetGrid.tiles[1]
        view.widgets = [upNext, weather, weather, small("clock"), small("system")]
        #expect(view.widgetGrid.tiles[1] === tile)
        #expect(visible(in: tile) == [tile.title] + tile.skeleton)
        #expect(tile.meters.arrangedSubviews.isEmpty)
        view.widgets = [upNext, small("value"), weather, small("clock"), small("system")]
        #expect(visible(in: tile) == [tile.value, tile.detail])
        #expect(tile.value.stringValue == "value")
    }

    @Test func aWidgetWithNothingToShowAppearsOnlyWhileEditingSoItCanBeRemoved() {
        var edits: [WidgetSettings.Edit] = []
        view.onWidgetEdit = { edits.append($0) }
        let music = WidgetGrid.Widget(
            id: "music", name: "Now Playing",
            content: .unavailable(title: "Now Playing", summary: "Music controls"), action: "",
            spoken: "Now Playing: Music controls", isWide: true)
        view.widgets = [small("clock"), music, small("system")]
        #expect(view.widgetGrid.shown.map(\.id) == ["clock", "system"])
        view.selectWidget(1)
        view.editWidgets()
        #expect(view.widgetGrid.shown.map(\.id) == ["clock", "music", "system"])
        #expect(view.selectedWidget == 2)
        view.layoutSubtreeIfNeeded()
        let tile = view.widgetGrid.tiles[1]
        #expect(visible(in: tile) == [tile.title, tile.headline])
        #expect(tile.title.stringValue == "NOW PLAYING")
        #expect(tile.headline.stringValue == "Music controls")
        #expect(tile.accessibilityLabel() == "Now Playing: Music controls")
        #expect(tile.frame.width > view.widgetGrid.tiles[0].frame.width * 2)
        press(kVK_LeftArrow, "\u{F702}")
        press(kVK_Delete, "\u{7F}")
        #expect(edits == [.remove("music")])
        view.finishEditingWidgets()
        #expect(view.widgetGrid.shown.map(\.id) == ["clock", "system"])
        #expect(view.selectedWidget == nil)
        view.widgets = [music]
        #expect(view.widgetGrid.isHidden)
    }

    private func visible(in tile: WidgetTile) -> [NSView] {
        let parts: [NSView] =
            [tile.title, tile.value, tile.headline] + tile.skeleton
            + [tile.detail, tile.span, tile.reason, tile.allow]
        return parts.filter { !$0.isHiddenOrHasHiddenAncestor }
    }

    private func small(_ id: String) -> WidgetGrid.Widget {
        .init(id: id, name: id, value: id, detail: "", action: "Open \(id)", spoken: id)
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
