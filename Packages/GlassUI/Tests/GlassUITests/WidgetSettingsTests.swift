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
        widgets.add("battery", from: Self.available)
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
        widgets.add("clock", from: Self.available)
        widgets.add("weather", from: Self.available)
        #expect(widgets == (try settings(#"{"custom": true, "added": ["clock"]}"#)))
        var defaults = WidgetSettings()
        defaults.add("system", from: Self.available)
        #expect(defaults == WidgetSettings())
    }

    @Test func savedWidgetsThatAreGoneOrRepeatedAreSkipped() throws {
        let widgets = try settings(
            #"{"custom": true, "added": ["weather", "system", "system", "clock"]}"#)
        #expect(widgets.added(from: Self.available) == ["system", "clock"])
    }
}
