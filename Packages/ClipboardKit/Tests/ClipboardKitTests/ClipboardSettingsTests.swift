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

        settings.retention = ClipboardStore.Retention(period: .init(7, .day), items: 100)

        let data = try JSONEncoder().encode(settings)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let retention = json?["retention"] as? [String: Any]
        let restored = try JSONDecoder().decode(ClipboardSettings.self, from: data)
        let empty = try JSONDecoder().decode(ClipboardSettings.self, from: Data("{}".utf8))

        #expect(json?["addedApps"] as? [String] == [Self.notes])
        #expect(json?["removedApps"] as? [String] == [Self.onePassword])
        #expect(retention?["period"] as? [String: AnyHashable] == ["count": 7, "unit": "days"])
        #expect(retention?["items"] as? Int == 100)
        #expect(restored == settings)
        #expect(empty == ClipboardSettings())
        #expect(empty.retention == ClipboardStore.Retention(period: .init(30, .day), items: 1_000))
    }

    @Test func keepsTheDefaultLimitsForMissingOrNonPositiveValues() throws {
        let saved = Data(#"{"retention": {"days": 0, "items": -5}}"#.utf8)
        let partial = Data(#"{"retention": {"days": 7}}"#.utf8)

        let invalid = try JSONDecoder().decode(ClipboardSettings.self, from: saved).retention
        let some = try JSONDecoder().decode(ClipboardSettings.self, from: partial).retention

        #expect(invalid == ClipboardStore.Retention())
        #expect(some == ClipboardStore.Retention(period: .init(7, .day), items: 1_000))
    }
}
