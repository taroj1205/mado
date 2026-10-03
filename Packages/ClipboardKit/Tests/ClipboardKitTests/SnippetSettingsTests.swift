import Foundation
import Testing

@testable import ClipboardKit

@Suite struct SnippetSettingsTests {
    private static let terminal = "com.apple.Terminal"
    private static let notes = "com.apple.Notes"
    private static let signOff = Snippet(name: "Email sign-off", keyword: #"\sig"#, text: "Bye")

    @Test func startsOnWithoutSnippetsAndOffInTerminal() throws {
        let settings = SnippetSettings()
        let earlier = try JSONDecoder().decode(SnippetSettings.self, from: Data("{}".utf8))

        #expect(settings.snippets.isEmpty)
        #expect(settings.expands(in: Self.notes))
        #expect(settings.expands(in: nil))
        #expect(!settings.expands(in: Self.terminal))
        #expect(settings.appsWithoutExpansion == [Self.terminal])
        #expect(earlier == settings)
    }

    @Test func turnsOffEverywhereWithTheSwitch() {
        var settings = SnippetSettings()

        settings.expands = false

        #expect(!settings.expands(in: Self.notes))
        #expect(!settings.expands(in: nil))
    }

    @Test func turnsExpansionOffAndOnPerApp() {
        var settings = SnippetSettings()

        settings.stopExpanding(in: Self.notes)
        settings.expandAgain(in: Self.terminal)

        #expect(!settings.expands(in: Self.notes))
        #expect(settings.expands(in: Self.terminal))
        #expect(settings.appsWithoutExpansion == [Self.notes])
    }

    @Test func savesReplacesAndRemovesSnippets() {
        var settings = SnippetSettings()
        let address = Snippet(name: "Home address", keyword: #"\addr"#, text: "1 Queen St")

        settings.save(Self.signOff)
        settings.save(address)
        var edited = Self.signOff
        edited.keyword = #"\bye"#
        settings.save(edited)
        let found = settings.snippet(withKeyword: #"\bye"#)
        settings.remove(address.id)

        #expect(found == edited)
        #expect(settings.snippet(withKeyword: #"\sig"#) == nil)
        #expect(settings.snippets == [edited])
    }

    @Test func keepsSnippetsAndAppsAcrossSaves() throws {
        var settings = SnippetSettings()
        settings.save(Self.signOff)
        settings.expands = false
        settings.stopExpanding(in: Self.notes)

        let data = try JSONEncoder().encode(settings)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let restored = try JSONDecoder().decode(SnippetSettings.self, from: data)

        #expect(restored == settings)
        #expect(json?["expands"] as? Bool == false)
        #expect(json?["addedApps"] as? [String] == [Self.notes])
        #expect((json?["removedApps"] as? [String])?.isEmpty == true)
        #expect((json?["snippets"] as? [[String: String]])?.first?["keyword"] == #"\sig"#)
    }

    @Test func findsKeywordsThatWouldHideEachOther() {
        var settings = SnippetSettings()
        settings.save(Self.signOff)
        let id = Self.signOff.id

        let shorter = settings.snippet(overlapping: #"\s"#, besides: nil)
        let inside = settings.snippet(overlapping: "i", besides: nil)
        let longer = settings.snippet(overlapping: #"\sign"#, besides: nil)
        let same = settings.snippet(overlapping: #"\sig"#, besides: nil)

        #expect([shorter, inside, longer, same].map { $0?.id } == [id, id, id, id])
        #expect(settings.snippet(overlapping: #"\sig"#, besides: id) == nil)
        #expect(settings.snippet(overlapping: "ig", besides: nil) == nil)
        #expect(settings.snippet(overlapping: ";fu", besides: nil) == nil)
    }
}
