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
        let json = try JSONSerialization.jsonObject(with: data) as? [String: [String]]
        let restored = try JSONDecoder().decode(ClipboardSettings.self, from: data)
        let empty = try JSONDecoder().decode(ClipboardSettings.self, from: Data("{}".utf8))

        #expect(json == ["addedApps": [Self.notes], "removedApps": [Self.onePassword]])
        #expect(restored == settings)
        #expect(empty == ClipboardSettings())
    }
}
