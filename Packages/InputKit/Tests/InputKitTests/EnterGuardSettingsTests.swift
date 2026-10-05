import Foundation
import Testing

@testable import InputKit

@Suite struct EnterGuardSettingsTests {
    private static let slack = "com.tinyspeck.slackmacgap"
    private static let chatGPT = EnterGuardSettings.builtIns[1].bundleIDs

    @Test func guardsTheBuiltInAppsByDefault() throws {
        let settings = try JSONDecoder().decode(EnterGuardSettings.self, from: Data("{}".utf8))

        #expect(settings.isOn)
        for app in EnterGuardSettings.builtIns.flatMap(\.bundleIDs) {
            #expect(settings.guards(app))
        }
        #expect(!settings.guards(Self.slack))
        #expect(!settings.guards(nil))
    }

    @Test func aBuiltInCanBeTurnedOffAndOnAgain() {
        var settings = EnterGuardSettings()
        settings.setGuarding(Self.chatGPT, false)

        #expect(Self.chatGPT.allSatisfy { !settings.guards($0) })

        settings.setGuarding(Self.chatGPT, true)

        #expect(Self.chatGPT.allSatisfy(settings.guards))
    }

    @Test func anAddedAppStaysListedWhenTurnedOff() throws {
        var settings = EnterGuardSettings()
        settings.add(Self.slack)
        settings.add(Self.slack)
        settings.setGuarding([Self.slack], false)

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(EnterGuardSettings.self, from: data)

        #expect(decoded == settings)
        #expect(decoded.addedApps == [Self.slack])
        #expect(!decoded.guards(Self.slack))
    }

    @Test func addingABuiltInTurnsItBackOnInsteadOfListingItTwice() {
        var settings = EnterGuardSettings()
        settings.setGuarding(Self.chatGPT, false)
        settings.add(Self.chatGPT[1])

        #expect(settings.addedApps.isEmpty)
        #expect(Self.chatGPT.allSatisfy(settings.guards))
    }

    @Test func savesTheSwitchUnderItsOwnNames() throws {
        var settings = EnterGuardSettings()
        settings.isOn = false
        settings.add(Self.slack)

        let data = try JSONEncoder().encode(settings)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains("\"on\":false"))
        #expect(json.contains("\"added_apps\""))
        #expect(try JSONDecoder().decode(EnterGuardSettings.self, from: data) == settings)
    }
}
