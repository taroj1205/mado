import AppCore
import CoreGraphics
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
        #expect(radial.haptics)
        #expect(radial.isEnabled)
        #expect(radial.trigger == [.function])
        #expect(radial.opensAt == .pointer)
        #expect(radial.showsPreview)
        #expect(!radial.showsLabel)
        #expect(radial.clickStepsCycle)
    }

    @Test func theHoleIsNeverStored() throws {
        var settings = Settings()

        try settings.setValue(RadialSettings(), for: "radial")

        guard case .object(let stored) = settings.modules["radial"] else {
            Issue.record("radial settings are not a JSON object")
            return
        }
        #expect(
            Set(stored.keys) == [
                "ring", "top", "topRight", "right", "bottomRight", "bottom", "bottomLeft",
                "left", "topLeft", "haptics", "isEnabled", "trigger", "opensAt", "showsPreview",
                "showsLabel", "clickStepsCycle",
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

    @Test func eachZoneTakesItsSlotsActionAndTheHoleDoesNothing() {
        var radial = RadialSettings()
        for (slot, action) in zip(Self.slots, RadialSettings.Action.allCases) {
            radial[keyPath: slot] = action
        }
        let zones: [RadialResolver.Zone] = [
            .ring, .direction(.top), .direction(.topRight), .direction(.right),
            .direction(.bottomRight), .direction(.bottom), .direction(.bottomLeft),
            .direction(.left), .direction(.topLeft),
        ]

        #expect(zones.map(radial.action(in:)) == Self.slots.map { radial[keyPath: $0] })
        #expect(radial.action(in: .cancel) == .nothing)
    }

    @Test func previewsLayoutsCyclesFromTheHalfAndFullScreenOverTheWholeScreen() {
        let screen = ScreenGeometry.Screen(
            frame: CGRect(x: 0, y: 0, width: 1_440, height: 900),
            visibleFrame: CGRect(x: 0, y: 66, width: 1_440, height: 810))
        let window = CGRect(x: 100, y: 200, width: 800, height: 600)
        func preview(_ action: RadialSettings.Action) -> CGRect? {
            action.previewFrame(of: window, on: screen, gap: 12)
        }
        func layout(_ action: LayoutEngine.Action) -> CGRect {
            LayoutEngine.frame(
                for: action, in: screen.visibleFrame, gap: 12, windowSize: window.size)
        }

        #expect(preview(.nothing) == nil)
        #expect(preview(.fullScreen) == screen.frame)
        #expect(preview(.topCycle) == layout(.topHalf))
        #expect(preview(.rightCycle) == layout(.rightHalf))
        #expect(preview(.bottomCycle) == layout(.bottomHalf))
        #expect(preview(.leftCycle) == layout(.leftHalf))
        #expect(preview(.centre) == layout(.centre))
        #expect(preview(.almostMaximize) == layout(.almostMaximize))
        #expect(preview(.bottomRightQuarter) == layout(.bottomRightQuarter))
        #expect(preview(.centreThird) == layout(.centreThird))
    }

    @Test func releasePlacesTheLayoutBehindEachActionAndNothingElse() {
        #expect(RadialSettings.Action.rightCycle.layout == .rightHalf)
        #expect(RadialSettings.Action.topLeftQuarter.layout == .topLeftQuarter)
        #expect(RadialSettings.Action.centre.layout == .centre)
        #expect(RadialSettings.Action.fullScreen.layout == nil)
        #expect(RadialSettings.Action.nothing.layout == nil)
    }

    @Test func onlyLeftAndRightHalvesFillBesideAWindowThatRefusedItsHalf() {
        let halves = RadialSettings.Action.allCases.filter { $0.half != nil }

        #expect(halves == [.rightCycle, .leftCycle, .rightHalf, .leftHalf])
        #expect(RadialSettings.Action.leftCycle.half == .left)
        #expect(RadialSettings.Action.rightHalf.half == .right)
    }

    @Test func turningHapticsOffSurvivesSavingAndLoading() throws {
        var radial = RadialSettings()
        radial.haptics = false

        #expect(try roundTrip(radial)?.haptics == false)
    }

    @Test func everyOptionSurvivesSavingAndLoading() throws {
        var radial = RadialSettings()
        radial.isEnabled = false
        radial.trigger = [.command, .shift]
        radial.opensAt = .screenCentre
        radial.showsPreview = false
        radial.showsLabel = true
        radial.clickStepsCycle = false

        #expect(try roundTrip(radial) == radial)
    }

    @Test func anOlderFileKeepsItsValuesAndTakesDefaultsForTheRest() throws {
        var settings = Settings()
        settings.modules["radial"] = .object([
            "left": .string("left_half"), "haptics": .bool(false),
        ])

        let radial = try #require(try settings.value(RadialSettings.self, for: "radial"))

        var expected = RadialSettings()
        expected.left = .leftHalf
        expected.haptics = false
        #expect(radial == expected)
    }
}
