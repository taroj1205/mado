import AppKit
import Testing

@testable import GlassUI

@MainActor
@Suite struct WidgetGalleryTests {
    private let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 760, height: 360),
        styleMask: [.borderless], backing: .buffered, defer: true)
    private let gallery = WidgetGallery()

    private var ids: [String] { gallery.shown.map(\.card.id) }

    init() {
        window.isReleasedWhenClosed = false
        window.contentView = gallery
        gallery.catalogue = [
            .init(id: "weather", name: "Weather", summary: "Now, high and low", group: .today),
            .init(id: "clock", name: "Clock", summary: "Time and date", group: .today),
            .init(
                id: "music", name: "Now Playing", summary: "Music controls", group: .media,
                isWide: true),
            .init(id: "battery", name: "Battery", summary: "Mac and devices", group: .system),
            .init(id: "system", name: "System", summary: "CPU and memory", group: .system),
        ]
        gallery.previews = [
            .init(
                id: "clock", name: "Clock", value: "9:41", detail: "Mon 5 Oct", action: "Open",
                spoken: "Time: 9:41")
        ]
        gallery.placed = ["clock": .panel, "battery": .rightTop]
        gallery.layoutSubtreeIfNeeded()
    }

    private func card(_ id: String) throws -> WidgetGalleryCard {
        try #require(gallery.cards.first { $0.card.id == id })
    }

    private func press(_ chip: Int) {
        gallery.chips[chip].performClick(nil)
        gallery.layoutSubtreeIfNeeded()
    }

    @Test func previewsSitInSixColumnsAtTheSizeTheyHaveInThePanel() throws {
        let cell = (732 - 5 * 8) / 6.0
        let clock = try card("clock")
        let music = try card("music")
        #expect(abs(try card("weather").frame.minX - 14) < 0.5)
        #expect(abs(clock.frame.minX - (14 + cell + 8)) < 0.5)
        #expect(abs(clock.tile.frame.width - cell) < 0.5)
        #expect(clock.tile.frame.height == 78)
        #expect(abs(music.tile.frame.width - (2 * cell + 8)) < 0.5)
        #expect(music.frame.minY == clock.frame.minY)
        #expect(try card("system").frame.minY == clock.frame.minY)
        #expect(clock.tile.value.stringValue == "9:41")
        #expect(try card("weather").tile.title.stringValue == "WEATHER")
        #expect(try card("weather").tile.headline.stringValue == "Now, high and low")
        let badge = clock.convert(clock.badge.frame, to: clock)
        #expect(badge.minX == -7 && badge.width == 22)
    }

    @Test func addedPreviewsShowAGreenTickAndWhereTheySit() throws {
        let clock = try card("clock")
        let weather = try card("weather")
        #expect(clock.badge.isAdded)
        #expect(!weather.badge.isAdded)
        #expect(clock.tile.alphaValue == 0.55)
        #expect(weather.tile.alphaValue == 1)
        #expect(clock.note.stringValue == "In the panel")
        #expect(try card("battery").note.stringValue == "Right · Top")
        #expect(weather.note.stringValue == "Now, high and low")
        #expect(clock.accessibilityLabel() == "Clock, added, In the panel. Show it")
        #expect(weather.accessibilityLabel() == "Add Weather")
        #expect(gallery.count.stringValue == "2 widgets added")
        gallery.placed = ["clock": .leftTop]
        #expect(clock.note.stringValue == "Left · Top")
        #expect(try !card("battery").badge.isAdded)
        #expect(gallery.count.stringValue == "1 widget added")
    }

    @Test func chipsNarrowThePreviewsToOneGroup() {
        #expect(gallery.chips.map(\.title) == ["All", "Today", "System", "Media", "Text"])
        #expect(gallery.chips.map(\.isOn) == [true, false, false, false, false])
        press(2)
        #expect(ids == ["battery", "system"])
        #expect(gallery.chips.map(\.isOn) == [false, false, true, false, false])
        #expect(gallery.cards.filter { !$0.isHidden }.map(\.card.id) == ids)
        #expect(gallery.empty.isHidden)
        press(4)
        #expect(ids.isEmpty)
        #expect(!gallery.empty.isHidden)
        #expect(gallery.emptyText.stringValue == "No text widgets yet")
        press(0)
        #expect(ids == ["weather", "clock", "music", "battery", "system"])
    }

    @Test func theSearchFieldFiltersByNameSummaryAndGroup() {
        gallery.query = "play"
        gallery.layoutSubtreeIfNeeded()
        #expect(ids == ["music"])
        gallery.query = " CPU "
        gallery.layoutSubtreeIfNeeded()
        #expect(ids == ["system"])
        gallery.query = "today"
        gallery.layoutSubtreeIfNeeded()
        #expect(ids == ["weather", "clock"])
        press(2)
        #expect(ids.isEmpty)
        #expect(gallery.emptyText.stringValue == "No widgets match “today”")
        gallery.query = "zzz"
        press(0)
        #expect(!gallery.empty.isHidden)
        #expect(gallery.emptyText.stringValue == "No widgets match “zzz”")
    }

    @Test func pressingAPreviewReportsItsWidget() throws {
        var picks: [String] = []
        gallery.onPick = { picks.append($0) }
        #expect(try card("weather").accessibilityPerformPress())
        #expect(try card("clock").accessibilityPerformPress())
        #expect(picks == ["weather", "clock"])
    }

    @Test func newDataRefreshesThePreviewsInPlace() throws {
        let clock = try card("clock")
        gallery.previews = [
            .init(
                id: "clock", name: "Clock", value: "9:42", detail: "Mon 5 Oct", action: "Open",
                spoken: "Time: 9:42")
        ]
        #expect(try card("clock") === clock)
        #expect(clock.tile.value.stringValue == "9:42")
    }
}
