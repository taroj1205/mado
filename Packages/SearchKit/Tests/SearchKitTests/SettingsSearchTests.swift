import Foundation
import Testing

@testable import SearchKit

@Suite struct SettingsSearchTests {
    private typealias Place = SettingsSearch.Place
    private typealias Entry = SettingsSearch.Entry
    private typealias Group = SettingsSearch.Group

    private static let general = Place(page: "General", tab: nil)
    private static let search = Place(page: "Search", tab: nil)
    private static let windows = Place(page: "Windows", tab: nil)
    private static let layouts = Place(page: "Windows", tab: "Layouts")
    private static let radial = Place(page: "Windows", tab: "Radial Menu")
    private static let clipboard = Place(page: "Clipboard", tab: nil)

    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let places = [general, search, clipboard, windows, layouts, radial]
    private let entries = [
        Entry(
            id: "hotkey", place: general, section: "Launcher", label: "Launcher hotkey",
            choices: ["⌘Space", "⌥Space"], isHotkey: true),
        Entry(
            id: "login", place: general, section: "Launcher", label: "Launch at login",
            keywords: ["startup"]),
        Entry(
            id: "temperature", place: search, section: "Units when none is named",
            label: "Temperature", choices: ["Celsius (°C)", "Fahrenheit (°F)"]),
        Entry(
            id: "currency", place: search, section: "Currency", label: "Default currency",
            choices: ["MXN · Mexican Peso"]),
        Entry(
            id: "history", place: clipboard, section: "Clipboard history", label: "Open history",
            isHotkey: true),
        Entry(
            id: "left", place: layouts, section: "Layouts", label: "Left Half", isHotkey: true),
        Entry(id: "ring", place: radial, section: "Radial menu", label: "Ring opens"),
        Entry(id: "radial", place: radial, section: "Radial menu", label: "Radial menu"),
    ]

    private func groups(_ query: String, _ history: SettingsSearch = .init()) -> [Group] {
        history.groups(for: query, in: entries, places: places, at: now)
    }

    private func ids(_ query: String, _ history: SettingsSearch = .init()) -> [String] {
        groups(query, history).flatMap { $0.suggestions.map(\.entry) }
    }

    @Test func groupsByPlaceWithTheBestGroupFirst() {
        let found = groups("hotk")

        #expect(found.map(\.place) == [Self.general, Self.clipboard, Self.layouts])
        #expect(found.map(\.title.string) == ["General", "Clipboard", "Windows › Layouts"])
        #expect(found.first?.suggestions.first?.title.matches == [9, 10, 11, 12])
        #expect(found.allSatisfy { !$0.isSelectable })
    }

    @Test func saysWhenAChoiceOrAnotherWordMatched() {
        let celsius = groups("cel").first?.suggestions.first
        #expect(celsius?.entry == "temperature")
        #expect(celsius?.title.matches.isEmpty == true)
        #expect(celsius?.note == SettingsSearch.Text(string: "Celsius (°C)", matches: [0, 1, 2]))

        let startup = groups("startup").first?.suggestions.first
        #expect(startup?.entry == "login")
        #expect(startup?.note?.string == "Also “startup”")
        #expect(startup?.note?.matches == Array(6..<13))
    }

    @Test func aMatchingTabNameBecomesASelectableHeader() {
        let found = groups("radial")

        #expect(found.first?.place == Self.radial)
        #expect(found.first?.isSelectable == true)
        #expect(found.first?.title.matches == Array(10..<16))
        #expect(found.first?.suggestions.map(\.entry) == ["radial", "ring"])
    }

    @Test func dropsScatteredMatchesAndEmptyQueries() {
        #expect(ids("lgnhlf").isEmpty)
        #expect(ids("caps").isEmpty)
        #expect(ids("   ").isEmpty)
        #expect(ids("zzz").isEmpty)
    }

    @Test func settingsYouGoToMoreRankHigher() {
        #expect(ids("h").prefix(2) == ["hotkey", "history"])

        var history = SettingsSearch()
        history.visit("history", at: now)
        history.visit("history", at: now)

        #expect(ids("h", history).first == "history")
    }

    @Test func keepsTheLastFiveSettingsYouWentTo() {
        var history = SettingsSearch()
        for id in ["a", "b", "c", "d", "e", "f", "c"] {
            history.visit(id, at: now)
        }
        #expect(history.recent == ["c", "f", "e", "d", "b"])

        history.forget("f")
        #expect(history.recent == ["c", "e", "d", "b"])

        history.clearRecent()
        #expect(history.recent.isEmpty)
    }

    @Test func recentSuggestionsSayWhereEachSettingLives() {
        var history = SettingsSearch()
        history.visit("left", at: now)
        history.visit("gone", at: now)

        let recent = history.recentSuggestions(in: entries)

        #expect(recent.map(\.entry) == ["left"])
        #expect(recent.first?.note?.string == "Windows › Layouts")
    }

    @Test func roundTripsThroughJSON() throws {
        var history = SettingsSearch()
        history.visit("login", at: now)

        let data = try JSONEncoder().encode(history)

        #expect(try JSONDecoder().decode(SettingsSearch.self, from: data) == history)
    }
}
