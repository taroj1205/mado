import AppKit
import Carbon.HIToolbox
import Testing

@testable import GlassUI

@MainActor
@Suite(.silentWindows) struct LyricsPaneTests {
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 760, height: 548),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    private let view = LauncherView()
    private let pasteboard = NSPasteboard(name: .init("LyricsPaneTests-\(UUID().uuidString)"))
    private let lines = ["", "Salt on the window", "Low tide, low tide", "Every rope", "Far shore"]

    private var pane: LyricsPane { view.lyricsPane }

    init() {
        panel.contentView = view
        view.lyricsPane.lines.reducesMotion = { true }
        view.lyricsPane.pasteboard = pasteboard
        view.results.sections = [
            .init(
                title: "Applications",
                items: [
                    .init(
                        id: "Lyricist", title: "Lyricist", subtitle: "", kind: "App",
                        symbol: "star", action: "Open Application")
                ])
        ]
        panel.makeFirstResponder(view.field)
    }

    private func verse(
        _ status: WidgetGrid.LyricsStatus, current: Int? = 2, playing: Bool = true
    ) -> WidgetGrid.Verse {
        .init(
            title: "Low Tide", artist: "Harbour Lights", artwork: nil, isPlaying: playing,
            status: status, lines: status == .synced || status == .plain ? lines : [],
            current: status == .synced ? current : nil, progress: 0.4, remaining: 3,
            position: 19.6, duration: 46)
    }

    private func feed(_ verse: WidgetGrid.Verse?) {
        view.widgetPreviews =
            verse.map { [.init(id: "lyrics", name: "Lyrics", verse: $0, action: "", spoken: "")] }
            ?? []
        view.layoutSubtreeIfNeeded()
    }

    private func open(_ verse: WidgetGrid.Verse?) {
        view.showLyrics(true)
        feed(verse)
    }

    @Test func showingThePaneHidesTheResultsAndTheActionCapsuleAndRefitsThePanel() {
        var fits = 0
        view.onFit = { fits += 1 }
        view.context = "6 results"
        open(verse(.synced))
        #expect(view.showsLyrics && view.results.isHidden && view.actionCapsule.isHidden)
        #expect(view.contextPill.isHidden)
        #expect(fits == 1)
        view.show(view.results.sections)
        #expect(view.results.isHidden)
        view.showLyrics(false)
        #expect(!view.showsLyrics && !view.results.isHidden && !view.actionCapsule.isHidden)
        #expect(fits == 2)
    }

    @Test func openingTheLyricsReplacesTheQuery() {
        var queries: [String] = []
        view.onQuery = { queries.append($0) }
        view.openLyrics()
        #expect(view.field.stringValue == "lyrics" && queries == ["lyrics"])
    }

    @Test func withNothingPlayingOnlyAQuietMessageShows() {
        open(nil)
        #expect(!pane.empty.isHidden && pane.body.isHidden)
        #expect(pane.empty.stringValue == "Nothing is playing")
        feed(verse(.synced))
        #expect(pane.empty.isHidden && !pane.body.isHidden)
    }

    @Test(arguments: [
        (WidgetGrid.LyricsStatus.synced, true, "Synced · LRCLIB", 4),
        (.plain, true, "Not synced", 3), (.instrumental, false, "", 1),
        (.missing, false, "", 1), (.loading, false, "", 1), (.off, false, "", 1),
    ])
    func eachStateShowsItsColumn(
        status: WidgetGrid.LyricsStatus, hasLines: Bool, badge: String, hints: Int
    ) {
        open(verse(status))
        #expect(pane.lines.isHidden == !hasLines)
        #expect(pane.note.isHidden == hasLines)
        #expect(pane.badge.isHidden == badge.isEmpty)
        if !badge.isEmpty {
            #expect(pane.badge.name.stringValue == badge)
        }
        #expect(pane.hints.shown.count == hints && pane.hints.shown.last?.title == "Close")
        #expect(pane.track.title.stringValue == "Low Tide")
        #expect(pane.track.progress.elapsed.stringValue == "0:19")
        #expect(pane.track.progress.total.stringValue == "0:46")
    }

    @Test func theNotesReadAsTheBoardWrites() {
        open(verse(.missing))
        #expect(pane.note.title.stringValue == "No lyrics for this track")
        #expect(pane.note.detail.stringValue == "Looked up by title, artist and length")
        #expect(pane.note.settings.isHidden)
        open(verse(.instrumental))
        #expect(pane.note.title.stringValue == "Instrumental" && pane.note.detail.isHidden)
        open(verse(.loading))
        #expect(pane.note.skeleton.allSatisfy { !$0.isHidden })
        #expect(pane.note.accessibilityLabel() == "Looking up lyrics")
        var opened = 0
        view.onLyricsSettings = { opened += 1 }
        open(verse(.off))
        #expect(pane.note.title.stringValue == "Lyrics are off" && !pane.note.settings.isHidden)
        pane.note.settings.performClick(nil)
        #expect(opened == 1)
    }

    @Test func arrowsBrowseAndReturnPlaysFromTheBrowsedLine() {
        var sought: [Int] = []
        view.onSeek = { sought.append($0) }
        open(verse(.synced))
        press(kVK_DownArrow, "\u{F701}")
        press(kVK_DownArrow, "\u{F701}")
        #expect(pane.lines.browsed == 4)
        press(kVK_UpArrow, "\u{F700}")
        #expect(pane.lines.focus == 3)
        press(kVK_Return, "\r")
        #expect(sought == [3] && pane.lines.browsed == nil)
        press(kVK_Return, "\r")
        #expect(sought == [3, 2])
        #expect(view.field.stringValue.isEmpty)
    }

    @Test func browsingStopsAtTheEnds() {
        open(verse(.synced))
        for _ in 0..<8 { press(kVK_DownArrow, "\u{F701}") }
        #expect(pane.lines.browsed == lines.count - 1)
        for _ in 0..<8 { press(kVK_UpArrow, "\u{F700}") }
        #expect(pane.lines.browsed == 0)
    }

    @Test func escapeEndsBrowsingFirstAndThenCloses() {
        var cancels = 0
        view.onCancel = { cancels += 1 }
        open(verse(.synced))
        press(kVK_DownArrow, "\u{F701}")
        press(kVK_Escape, "\u{1B}")
        #expect(pane.lines.browsed == nil && cancels == 0)
        press(kVK_Escape, "\u{1B}")
        #expect(cancels == 1)
    }

    @Test func plainTextStillTypesIntoTheSearchField() throws {
        var queries: [String] = []
        view.onQuery = { queries.append($0) }
        open(verse(.synced))
        let editor = try #require(view.field.currentEditor() as? NSTextView)
        editor.insertText("ly", replacementRange: editor.selectedRange())
        #expect(view.field.stringValue == "ly" && queries == ["ly"])
    }

    @Test func commandCCopiesTheCurrentOrBrowsedLine() {
        open(verse(.synced))
        press(kVK_ANSI_C, "c", [.command])
        #expect(pasteboard.string(forType: .string) == "Low tide, low tide")
        press(kVK_DownArrow, "\u{F701}")
        press(kVK_ANSI_C, "c", [.command])
        #expect(pasteboard.string(forType: .string) == "Every rope")
    }

    @Test func plainLyricsCopyWholeAndCannotSeek() {
        var sought: [Int] = []
        view.onSeek = { sought.append($0) }
        open(verse(.plain))
        press(kVK_ANSI_C, "c", [.command])
        #expect(pasteboard.string(forType: .string) == lines.joined(separator: "\n"))
        press(kVK_Return, "\r")
        let middle = NSPoint(x: 20, y: pane.lines.bounds.midY)
        #expect(sought.isEmpty && pane.lines.line(at: middle) == nil)
        #expect(pane.lines.rows.allSatisfy { $0.element.accessibilityRole() == .staticText })
    }

    @Test func clickingOrPressingALineSeeksToIt() throws {
        var sought: [Int] = []
        view.onSeek = { sought.append($0) }
        open(verse(.synced))
        let column = pane.lines
        let anchor = LyricsPaneLines.anchor
        #expect(column.line(at: NSPoint(x: 20, y: anchor)) == 2)
        #expect(column.line(at: NSPoint(x: 20, y: anchor + LyricsPaneLines.pitch)) == 3)
        #expect(column.line(at: NSPoint(x: 20, y: anchor - LyricsPaneLines.pitch)) == 1)
        let row = try #require(column.rows.last?.element)
        #expect(row.accessibilityRole() == .button)
        #expect(row.accessibilityHelp() == "Play from this line")
        #expect(row.accessibilityPerformPress())
        #expect(sought == [4])
    }

    @Test func thePaneIsAGroupAndTheCurrentLineUpdatesInPlace() {
        open(verse(.synced))
        #expect(pane.accessibilityRole() == .group && pane.accessibilityLabel() == "Lyrics")
        #expect(pane.lines.now.accessibilityValue() as? String == "Low tide, low tide")
        feed(verse(.synced, current: 0))
        #expect(pane.lines.now.accessibilityValue() as? String == "Instrumental break")
    }

    @Test func neighboursFadeAndShrinkByDistance() {
        open(verse(.synced))
        let spots = (0..<lines.count).map(pane.lines.spot(of:))
        #expect(spots.map(\.opacity) == [0.32, 0.55, 1, 0.55, 0.32])
        #expect(spots[2].scale == 1 && abs(spots[0].scale - 0.9) < 0.001)
        #expect(spots[2].centre == LyricsPaneLines.anchor)
    }

    @Test func transportCallsSkipAndPlayPause() {
        var skips: [WidgetGrid.Skip] = []
        var toggles = 0
        view.onSkip = { skips.append($0) }
        view.onPlayPause = { toggles += 1 }
        open(verse(.synced, playing: false))
        #expect(pane.track.play.accessibilityLabel() == "Play")
        pane.track.previous.performClick(nil)
        pane.track.next.performClick(nil)
        pane.track.play.performClick(nil)
        #expect(skips == [.previous, .next] && toggles == 1)
    }

    @Test func gapDotsFillOneByOne() {
        #expect(LyricDots.level(of: 0, at: 0) == LyricDots.rest)
        #expect(LyricDots.level(of: 0, at: 0.4) == 1)
        #expect(LyricDots.level(of: 1, at: 0.4) > LyricDots.rest)
        #expect(LyricDots.level(of: 2, at: 0.4) == LyricDots.rest)
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
