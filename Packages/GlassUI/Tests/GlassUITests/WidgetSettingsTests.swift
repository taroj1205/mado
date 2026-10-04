import AppCore
import Foundation
import Testing

@testable import GlassUI

@Suite struct WidgetSettingsTests {
    private static let available = ["clock", "system", "battery"]

    private func settings(_ json: String) throws -> WidgetSettings {
        try JSONDecoder().decode(WidgetSettings.self, from: Data(json.utf8))
    }

    @Test func everyAvailableWidgetIsAddedByDefaultInCatalogueOrder() {
        #expect(WidgetSettings().added(from: Self.available) == Self.available)
    }

    @Test func addingPutsTheWidgetLastAndSurvivesSavingAndLoading() throws {
        var widgets = try settings(#"{"custom": true, "added": ["system", "clock"]}"#)
        widgets.apply(.add("battery"), from: Self.available)
        #expect(widgets.added(from: Self.available) == ["system", "clock", "battery"])
        let store = SettingsStore(
            url: FileManager.default.temporaryDirectory.appending(
                path: "\(UUID().uuidString)/settings.json"))
        defer { try? FileManager.default.removeItem(at: store.url.deletingLastPathComponent()) }
        var saved = Settings()
        try saved.setValue(widgets, for: "widgets")

        try store.save(saved)

        let loaded = try store.load().value(WidgetSettings.self, for: "widgets")
        #expect(loaded?.added(from: Self.available) == ["system", "clock", "battery"])
    }

    @Test func addingAWidgetThatIsAlreadyThereOrUnknownChangesNothing() throws {
        var widgets = try settings(#"{"custom": true, "added": ["clock"]}"#)
        widgets.apply(.add("clock"), from: Self.available)
        widgets.apply(.add("weather"), from: Self.available)
        #expect(widgets == (try settings(#"{"custom": true, "added": ["clock"]}"#)))
        var defaults = WidgetSettings()
        defaults.apply(.add("system"), from: Self.available)
        #expect(defaults == WidgetSettings())
    }

    @Test func movingPutsTheWidgetBeforeItsTargetOrLast() {
        var widgets = WidgetSettings()
        widgets.apply(.move("battery", before: "clock"), from: Self.available)
        #expect(widgets.added(from: Self.available) == ["battery", "clock", "system"])
        widgets.apply(.move("battery", before: nil), from: Self.available)
        #expect(widgets.added(from: Self.available) == ["clock", "system", "battery"])
        widgets.apply(.move("clock", before: "battery"), from: Self.available)
        #expect(widgets.added(from: Self.available) == ["system", "clock", "battery"])
    }

    @Test func movingOntoItselfOrAWidgetThatIsNotAddedChangesNothing() throws {
        var widgets = try settings(#"{"custom": true, "added": ["clock", "system"]}"#)
        let before = widgets
        widgets.apply(.move("clock", before: "clock"), from: Self.available)
        widgets.apply(.move("battery", before: "clock"), from: Self.available)
        widgets.apply(.move("weather", before: nil), from: Self.available)
        #expect(widgets == before)
        var defaults = WidgetSettings()
        defaults.apply(.move("weather", before: "clock"), from: Self.available)
        #expect(defaults == WidgetSettings())
    }

    @Test func removingTakesOnlyThatWidgetAndTheLastOneLeavesNone() {
        var widgets = WidgetSettings()
        widgets.apply(.remove("system"), from: Self.available)
        #expect(widgets.added(from: Self.available) == ["clock", "battery"])
        widgets.apply(.remove("weather"), from: Self.available)
        widgets.apply(.remove("system"), from: Self.available)
        #expect(widgets.added(from: Self.available) == ["clock", "battery"])
        widgets.apply(.remove("clock"), from: Self.available)
        widgets.apply(.remove("battery"), from: Self.available)
        #expect(widgets.added(from: Self.available).isEmpty)
        widgets.apply(.add("system"), from: Self.available)
        #expect(widgets.added(from: Self.available) == ["system"])
    }

    @Test func editsKeepSavedWidgetsThatAreNotAvailableNow() throws {
        var widgets = try settings(#"{"custom": true, "added": ["weather", "clock", "system"]}"#)
        widgets.apply(.move("system", before: "clock"), from: Self.available)
        widgets.apply(.remove("clock"), from: Self.available)
        #expect(widgets == (try settings(#"{"custom": true, "added": ["weather", "system"]}"#)))
    }

    @Test func savedWidgetsThatAreGoneOrRepeatedAreSkipped() throws {
        let widgets = try settings(
            #"{"custom": true, "added": ["weather", "system", "system", "clock"]}"#)
        #expect(widgets.added(from: Self.available) == ["system", "clock"])
    }
}
