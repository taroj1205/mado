import AppCore
import Foundation
import Testing

@testable import WindowKit

@Suite struct GestureSettingsTests {
    @Test func theDefaultsMatchThePlan() {
        let gestures = GestureSettings()
        #expect(gestures.move == [.function, .control])
        #expect(gestures.resize == [.function, .control, .option])
    }

    @Test func missingKeysKeepTheirDefaults() throws {
        let decoded = try JSONDecoder().decode(
            GestureSettings.self, from: Data(#"{"move": 1}"#.utf8))
        #expect(decoded.move == [.command])
        #expect(decoded.resize == GestureSettings().resize)
    }

    @Test func savedTriggersSurviveARoundTrip() throws {
        var gestures = GestureSettings()
        gestures.move = [.control, .option]
        gestures.resize = [.control, .option, .shift]
        var settings = Settings()
        try settings.setValue(gestures, for: "gestures")
        #expect(try settings.value(GestureSettings.self, for: "gestures") == gestures)
    }
}
