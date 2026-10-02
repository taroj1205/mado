import AppCore
import Foundation
import Testing

@testable import WindowKit

@Suite struct GestureSettingsTests {
    @Test func theDefaultsMatchThePlan() {
        let gestures = GestureSettings()
        #expect(gestures.move == [.function, .control])
        #expect(gestures.resize == [.function, .control, .option])
        #expect(gestures.target == .activeWindow)
    }

    @Test func missingKeysKeepTheirDefaults() throws {
        let decoded = try JSONDecoder().decode(
            GestureSettings.self, from: Data(#"{"move": 1}"#.utf8))
        #expect(decoded.move == [.command])
        #expect(decoded.resize == GestureSettings().resize)
        #expect(decoded.target == .activeWindow)
    }

    @Test func theTargetIsStoredByName() throws {
        let decoded = try JSONDecoder().decode(
            GestureSettings.self, from: Data(#"{"target": "under_mouse"}"#.utf8))
        #expect(decoded.target == .underMouse)
        #expect(decoded.move == GestureSettings().move)
    }

    @Test func savedTriggersSurviveARoundTrip() throws {
        var gestures = GestureSettings()
        gestures.move = [.control, .option]
        gestures.resize = [.control, .option, .shift]
        gestures.target = .underMouse
        var settings = Settings()
        try settings.setValue(gestures, for: "gestures")
        #expect(try settings.value(GestureSettings.self, for: "gestures") == gestures)
    }
}
