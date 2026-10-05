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

    @Test func placingAWidgetThatIsNotAddedAddsItAtThatSpot() throws {
        var widgets = try settings(#"{"custom": true, "added": ["clock", "system"]}"#)
        widgets.apply(.place("battery", .leftTop, before: "system"), from: Self.available)
        #expect(widgets.added(from: Self.available) == ["clock", "battery", "system"])
        #expect(widgets.spots(.custom, from: Self.available)["battery"] == .leftTop)
        let before = widgets
        widgets.apply(.place("weather", .leftTop, before: nil), from: Self.available)
        #expect(widgets == before)
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

    @Test func eachPlacementGivesEveryAddedWidgetItsOwnSpot() {
        let widgets = WidgetSettings()
        let ids = Self.available
        #expect(
            widgets.spots(.inPanel, from: ids) == [
                "clock": .panel, "system": .panel, "battery": .panel,
            ])
        #expect(
            widgets.spots(.above, from: ids) == [
                "clock": .aboveLeft, "system": .above(column: 1, row: 0), "battery": .aboveCentre,
            ])
        #expect(
            widgets.spots(.above, from: ids, wide: ["clock"]) == [
                "clock": .aboveLeft, "system": .aboveCentre, "battery": .above(column: 3, row: 0),
            ])
        #expect(
            widgets.spots(.around, from: ids) == [
                "clock": .leftTop, "system": .beside(.left, row: 1), "battery": .rightTop,
            ])
    }

    @Test func aboveWrapsOntoAHigherRowOnceSixColumnsAreFull() {
        let ids = (1...8).map { "\($0)" }
        let spots = WidgetSettings().spots(.above, from: ids, wide: ["1"])
        #expect(spots["1"] == .above(column: 0, row: 1))
        #expect(spots["5"] == .above(column: 5, row: 1))
        #expect(spots["6"] == .above(column: 0, row: 0))
        #expect(spots["8"] == .aboveCentre)
    }

    @Test func groupingPutsTheWidgetsTogetherAndSplittingGivesEachItsOwnSpot() throws {
        var widgets = try settings(#"{"custom": true, "added": ["clock", "system", "battery"]}"#)
        widgets.apply(.group(["battery", "clock"], .rightTop, before: nil), from: Self.available)
        #expect(widgets.added(from: Self.available) == ["system", "battery", "clock"])
        #expect(
            widgets.spots(.custom, from: Self.available) == [
                "clock": .rightTop, "system": .panel, "battery": .rightTop,
            ])
        widgets.apply(
            .spread(["battery": .rightTop, "clock": .rightMiddle, "weather": .leftTop]),
            from: Self.available)
        #expect(
            widgets.spots(.custom, from: Self.available) == [
                "clock": .rightMiddle, "system": .panel, "battery": .rightTop,
            ])
    }

    @Test func movingOneWidgetPlacesItAndMovingSeveralGroupsThem() {
        #expect(
            WidgetSettings.Edit.moving(["clock"], to: .leftTop, before: nil)
                == .place("clock", .leftTop, before: nil))
        #expect(
            WidgetSettings.Edit.moving(["clock", "system"], to: .leftTop, before: "battery")
                == .group(["clock", "system"], .leftTop, before: "battery"))
    }

    @Test func spotsSaveAsNamesAndOldNamesStillLoad() throws {
        let spots: [WidgetGrid.Spot] = [
            .panel, .aboveRight, .above(column: 3, row: 2), .beside(.right, row: 3),
        ]
        let data = try JSONEncoder().encode(spots)
        #expect(
            String(bytes: data, encoding: .utf8)
                == #"["in_panel","above_right","above:3:2","right:0:3"]"#)
        #expect(try JSONDecoder().decode([WidgetGrid.Spot].self, from: data) == spots)
        let old = Data(#"["above_centre","left_bottom","left:0:9","above:-1:0"]"#.utf8)
        #expect(
            try JSONDecoder().decode([WidgetGrid.Spot].self, from: old) == [
                .aboveCentre, .leftBottom, .leftBottom, .aboveLeft,
            ])
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([WidgetGrid.Spot].self, from: Data(#"["nowhere"]"#.utf8))
        }
    }

    @Test func customSpotsComeBackFromSavedSettingsAndDefaultToThePanel() throws {
        var widgets = try settings(
            #"{"custom": true, "added": ["clock", "system"], "#
                + #""spots": {"system": "right_bottom", "weather": "left_top"}}"#)
        #expect(
            widgets.spots(.custom, from: Self.available) == [
                "clock": .panel, "system": .rightBottom,
            ])
        widgets.apply(.remove("system"), from: Self.available)
        widgets.apply(.add("system"), from: Self.available)
        #expect(
            widgets.spots(.custom, from: Self.available) == ["clock": .panel, "system": .panel])
        let older = try settings(#"{"custom": true, "added": ["clock"]}"#)
        #expect(older.spots(.custom, from: Self.available) == ["clock": .panel])
    }
}
