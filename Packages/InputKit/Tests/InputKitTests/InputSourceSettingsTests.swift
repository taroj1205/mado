import Foundation
import Testing

@testable import InputKit

@Suite struct InputSourceSettingsTests {
    @Test func roundTripsEachAppDefault() throws {
        var settings = InputSourceSettings()
        settings.apps = [
            "com.apple.Terminal": .source(id: "com.apple.keylayout.ABC"),
            "com.apple.MobileSMS": .lastUsed,
        ]

        let data = try JSONEncoder().encode(settings)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains("\"last_used\""))
        #expect(try JSONDecoder().decode(InputSourceSettings.self, from: data) == settings)
    }

    @Test func startsEmptyWhenNothingIsSaved() throws {
        let settings = try JSONDecoder().decode(InputSourceSettings.self, from: Data("{}".utf8))

        #expect(settings.apps.isEmpty)
    }
}
