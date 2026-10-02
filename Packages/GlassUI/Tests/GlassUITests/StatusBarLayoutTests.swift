import AppCore
import Foundation
import Testing

@testable import GlassUI

@Suite struct StatusBarLayoutTests {
    private let pills = [
        pill("cpu"), pill("disk"), pill("wifi", shownByDefault: false), pill("thermal"),
    ]

    private static func pill(_ id: String, shownByDefault: Bool = true) -> StatusBar.Pill {
        .init(
            id: id, name: id, symbol: "cpu", value: "1", action: "Open",
            shownByDefault: shownByDefault)
    }

    private func ids(_ layout: StatusBarLayout, among pills: [StatusBar.Pill]) -> [String] {
        layout.arrange(pills).map(\.id)
    }

    private func ids(_ layout: StatusBarLayout) -> [String] {
        ids(layout, among: pills)
    }

    @Test func theDefaultShowsEveryPillThatIsOnByDefaultInItsOrder() {
        #expect(ids(StatusBarLayout()) == ["cpu", "disk", "thermal"])
    }

    @Test func aPillTurnedOnJoinsTheEndAndOneTurnedOffLeaves() {
        var layout = StatusBarLayout()
        layout.show("wifi", true, among: pills)
        #expect(ids(layout) == ["cpu", "disk", "thermal", "wifi"])
        layout.show("cpu", false, among: pills)
        #expect(ids(layout) == ["disk", "thermal", "wifi"])
        layout.show("cpu", true, among: pills)
        #expect(ids(layout) == ["disk", "thermal", "wifi", "cpu"])
    }

    @Test func turningOnAShownPillChangesNothing() {
        var layout = StatusBarLayout()
        layout.show("disk", true, among: pills)
        #expect(layout == StatusBarLayout())
    }

    @Test func movingPutsThePillBeforeTheTargetOrAtTheEnd() {
        var layout = StatusBarLayout()
        layout.move("thermal", before: "cpu", among: pills)
        #expect(ids(layout) == ["thermal", "cpu", "disk"])
        layout.move("thermal", before: nil, among: pills)
        #expect(ids(layout) == ["cpu", "disk", "thermal"])
        layout.move("disk", before: "disk", among: pills)
        #expect(ids(layout) == ["cpu", "disk", "thermal"])
    }

    @Test func aPillThatIsAwayKeepsItsPlaceWhileOthersMove() {
        var layout = StatusBarLayout()
        let away = pills.filter { $0.id != "disk" }
        layout.move("thermal", before: "cpu", among: away)
        #expect(ids(layout, among: away) == ["thermal", "cpu"])
        #expect(ids(layout) == ["thermal", "cpu", "disk"])
    }

    @Test func aPillAddedLaterFollowsItsOwnDefault() {
        var layout = StatusBarLayout()
        layout.move("thermal", before: "cpu", among: pills)
        let later = pills + [Self.pill("vpn"), Self.pill("focus", shownByDefault: false)]
        #expect(ids(layout, among: later) == ["thermal", "cpu", "disk", "vpn"])
    }

    @Test func theSavedLayoutComesBackInTheSameOrder() throws {
        var layout = StatusBarLayout()
        layout.show("wifi", true, among: pills)
        layout.show("cpu", false, among: pills)
        layout.move("wifi", before: "disk", among: pills)
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SettingsStore(url: dir.appending(path: "settings.json"))
        var settings = Settings()
        try settings.setValue(layout, for: "status_bar")
        try store.save(settings)

        let saved = try store.load().value(StatusBarLayout.self, for: "status_bar")
        #expect(saved == layout)
        #expect(saved.map { ids($0) } == ["wifi", "disk", "thermal"])
    }
}
