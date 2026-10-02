import AppCore
import Foundation
import Testing

@testable import WindowKit

@Suite struct RadialSettingsTests {
    private static var slots: [WritableKeyPath<RadialSettings, RadialSettings.Action>] {
        [
            \.ring, \.top, \.topRight, \.right, \.bottomRight, \.bottom, \.bottomLeft, \.left,
            \.topLeft,
        ]
    }

    private func roundTrip(_ radial: RadialSettings) throws -> RadialSettings? {
        let store = SettingsStore(
            url: FileManager.default.temporaryDirectory.appending(
                path: "\(UUID().uuidString)/settings.json"))
        defer { try? FileManager.default.removeItem(at: store.url.deletingLastPathComponent()) }
        var settings = Settings()
        try settings.setValue(radial, for: "radial")
        try store.save(settings)
        return try store.load().value(RadialSettings.self, for: "radial")
    }

    @Test func theDefaultsMatchTheCanvas() {
        let radial = RadialSettings()
        #expect(radial.ring == .maximize)
        #expect(radial.top == .topCycle)
        #expect(radial.topRight == .topRightQuarter)
        #expect(radial.right == .rightCycle)
        #expect(radial.bottomRight == .bottomRightQuarter)
        #expect(radial.bottom == .bottomCycle)
        #expect(radial.bottomLeft == .bottomLeftQuarter)
        #expect(radial.left == .leftCycle)
        #expect(radial.topLeft == .topLeftQuarter)
    }

    @Test func theRingAndEightDirectionsAreTheOnlyStoredSlots() throws {
        var settings = Settings()

        try settings.setValue(RadialSettings(), for: "radial")

        guard case .object(let stored) = settings.modules["radial"] else {
            Issue.record("radial settings are not a JSON object")
            return
        }
        #expect(
            Set(stored.keys) == [
                "ring", "top", "topRight", "right", "bottomRight", "bottom", "bottomLeft",
                "left", "topLeft",
            ])
    }

    @Test(arguments: RadialSettings.Action.allCases)
    func everySlotKeepsAnyActionThroughSavingAndLoading(action: RadialSettings.Action) throws {
        var radial = RadialSettings()
        for slot in Self.slots {
            radial[keyPath: slot] = action
        }

        let loaded = try #require(try roundTrip(radial))

        #expect(loaded == radial)
        #expect(Self.slots.allSatisfy { loaded[keyPath: $0] == action })
    }

    @Test func differentActionsInEverySlotSurviveSavingAndLoading() throws {
        var radial = RadialSettings()
        for (slot, action) in zip(Self.slots, RadialSettings.Action.allCases.reversed()) {
            radial[keyPath: slot] = action
        }

        #expect(try roundTrip(radial) == radial)
    }
}
