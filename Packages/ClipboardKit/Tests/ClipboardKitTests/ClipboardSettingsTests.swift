import Foundation
import Testing

@testable import ClipboardKit

@Suite struct ClipboardSettingsTests {
    private static let onePassword = "com.1password.1password"
    private static let notes = "com.apple.Notes"

    @Test func ignoresPasswordManagersByDefault() {
        let settings = ClipboardSettings()

        #expect(settings.ignores(any: [Self.onePassword]))
        #expect(settings.ignores(any: ["com.apple.Passwords"]))
        #expect(settings.ignores(any: [Self.notes, Self.onePassword]))
        #expect(!settings.ignores(any: [Self.notes]))
        #expect(!settings.ignores(any: []))
    }

    @Test func addsAndRemovesApps() {
        var settings = ClipboardSettings()

        settings.ignore(Self.notes)
        settings.ignore(Self.notes)
        let added = settings.ignoredApps.filter { $0 == Self.notes }.count
        settings.stopIgnoring(Self.notes)
        settings.stopIgnoring(Self.onePassword)

        #expect(added == 1)
        #expect(!settings.ignores(any: [Self.notes, Self.onePassword]))
        #expect(settings.ignores(any: ["com.bitwarden.desktop"]))
    }

    @Test func ignoresARemovedDefaultAgainOnceReAdded() {
        var settings = ClipboardSettings()

        settings.stopIgnoring(Self.onePassword)
        settings.ignore(Self.onePassword)

        #expect(settings == ClipboardSettings())
    }

    @Test func keepsChangesAcrossSavesAndNewDefaults() throws {
        var settings = ClipboardSettings()
        settings.ignore(Self.notes)
        settings.stopIgnoring(Self.onePassword)

        let data = try JSONEncoder().encode(settings)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let restored = try JSONDecoder().decode(ClipboardSettings.self, from: data)
        let empty = try JSONDecoder().decode(ClipboardSettings.self, from: Data("{}".utf8))

        #expect(json?["addedApps"] as? [String] == [Self.notes])
        #expect(json?["removedApps"] as? [String] == [Self.onePassword])
        #expect(restored == settings)
        #expect(empty == ClipboardSettings())
    }

    @Test func keepsTheChosenRetention() throws {
        var settings = ClipboardSettings()
        settings.retention = ClipboardStore.Retention(days: 7, items: 500)

        let restored = try JSONDecoder().decode(
            ClipboardSettings.self, from: JSONEncoder().encode(settings))

        #expect(ClipboardSettings().retention == ClipboardStore.Retention(days: 30, items: 1_000))
        #expect(restored.retention == ClipboardStore.Retention(days: 7, items: 500))
    }

    @Test(arguments: [#"{"days": 0, "items": 500}"#, #"{"days": 7, "items": -1}"#])
    func fallsBackToTheDefaultRetentionWhenTheSavedOneKeepsNothing(_ saved: String) throws {
        let restored = try JSONDecoder().decode(
            ClipboardSettings.self, from: Data(#"{"retention": \#(saved)}"#.utf8))

        #expect(restored.retention == ClipboardStore.Retention())
    }
}
