import AppCore
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

    @Test func tapsLeftCommandForEisuAndRightCommandForKanaByDefault() throws {
        let settings = try JSONDecoder().decode(InputSourceSettings.self, from: Data("{}".utf8))

        #expect(settings.hotKey(for: .english) == .modifierTap(.leftCommand))
        #expect(settings.hotKey(for: .japanese) == .modifierTap(.rightCommand))
        #expect(settings.hotKey(for: .next) == nil)
    }

    @Test func aClearedKeyStaysClearedAfterSaving() throws {
        var settings = InputSourceSettings()
        settings.bind(nil, to: .english)

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(InputSourceSettings.self, from: data)

        #expect(decoded.hotKey(for: .english) == nil)
        #expect(decoded.hotKey(for: .japanese) == .modifierTap(.rightCommand))
        #expect(decoded == settings)
    }

    @Test func aKeyMovesToTheTargetItWasLastGiven() {
        var settings = InputSourceSettings()
        settings.bind(.modifierTap(.leftCommand), to: .source(id: "com.apple.keylayout.US"))

        #expect(settings.hotKey(for: .english) == nil)
        #expect(
            settings.hotKey(for: .source(id: "com.apple.keylayout.US"))
                == .modifierTap(.leftCommand))
    }

    @Test func rebindingKeepsTheTargetInPlace() {
        var settings = InputSourceSettings()
        settings.bind(.modifierTap(.leftOption), to: .english)

        #expect(settings.keys.map(\.target) == [.english, .japanese])
        #expect(settings.hotKey(for: .english) == .modifierTap(.leftOption))
    }

    @Test func storesEachTargetUnderItsOwnName() throws {
        var settings = InputSourceSettings()
        settings.bind(.modifierTap(.rightOption), to: .next)
        settings.bind(.modifierTap(.leftShift), to: .source(id: "com.apple.keylayout.ABC"))

        let data = try JSONEncoder().encode(settings)
        let json = try #require(String(data: data, encoding: .utf8))

        for name in ["eisu", "kana", "next_source", "com.apple.keylayout.ABC"] {
            #expect(json.contains(name))
        }
        #expect(try JSONDecoder().decode(InputSourceSettings.self, from: data) == settings)
    }
}
