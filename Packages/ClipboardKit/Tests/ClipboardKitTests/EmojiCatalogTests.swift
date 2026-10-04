import Testing

@testable import ClipboardKit

@Suite struct EmojiCatalogTests {
    private static let data = """
        # comment
        @Smileys & Emotion
        😄\tgrinning face with smiling eyes\thappy|laugh|smile\t
        😍\tsmiling face with heart-eyes\tlove\t
        @People & Body
        👍\tthumbs up\t+1|good|hand\t1
        ☝️\tindex pointing up\tfinger\t1
        🧑‍💻\ttechnologist\tcoder\t1
        @Symbols
        💙\tblue heart\tlove\t
        ❤️\tred heart\tlove\t
        🆕\tNEW button\tnew\t
        """

    private let catalog = EmojiCatalog(data: Self.data) { $0 != "🆕" }

    @Test func groupsEmojiAndSkipsOnesTheSystemCannotDraw() {
        #expect(catalog.groups.map(\.name) == ["Smileys & Emotion", "People & Body", "Symbols"])
        #expect(catalog.groups.map(\.emoji.count) == [2, 3, 2])
        #expect(catalog.emoji("🆕") == nil)
        #expect(catalog.emoji("👍")?.takesTone == true)
    }

    @Test func findsNamesBeforeKeywordsBeforePrefixesAndShortNamesFirst() {
        #expect(catalog.search(":smile").map(\.character) == ["😄"])
        #expect(catalog.search("heart").map(\.character) == ["💙", "❤️", "😍"])
        #expect(catalog.search("hear").map(\.character) == ["💙", "❤️", "😍"])
        #expect(catalog.search("blue_heart:").map(\.character) == ["💙"])
        #expect(catalog.search("love").map(\.character) == ["💙", "❤️", "😍"])
        #expect(catalog.search("smiling").map(\.character) == ["😄", "😍"])
        #expect(catalog.search("red heart").map(\.character) == ["❤️"])
        #expect(catalog.search("HAND").map(\.character) == ["👍"])
        #expect(catalog.search("  ").isEmpty)
    }

    @Test func putsAnExactNameFirst() {
        let hearts = "@Symbols\n💗\tgrowing heart\t\t\n❤️\theart\t\t\n"

        #expect(
            EmojiCatalog(data: hearts) { _ in true }.search("heart").map(\.character)
                == ["❤️", "💗"])
    }

    @Test func writesShortcodesFromNames() {
        #expect(catalog.emoji("💙")?.shortcode == ":blue_heart:")
        #expect(catalog.emoji("😍")?.shortcode == ":smiling_face_with_heart_eyes:")
    }

    @Test func addsTheSkinToneAfterTheFirstScalar() throws {
        let thumbs = try #require(catalog.emoji("👍"))
        let pointing = try #require(catalog.emoji("☝️"))
        let technologist = try #require(catalog.emoji("🧑‍💻"))

        #expect(thumbs.toned(.medium) == "👍🏽")
        #expect(thumbs.toned(.standard) == "👍")
        #expect(pointing.toned(.dark) == "☝🏿")
        #expect(technologist.toned(.light) == "🧑🏻‍💻")
        #expect(catalog.emoji("💙")?.toned(.dark) == "💙")
    }

    @Test func loadsTheBundledCatalog() throws {
        let bundled = try #require(EmojiCatalog.bundled())

        #expect(bundled.groups.count == 9)
        #expect(bundled.search("smile").prefix(3).map(\.character).contains("😀"))
        #expect(bundled.search("heart").prefix(24).allSatisfy { $0.name.contains("heart") })
        #expect(bundled.emoji("😄")?.name == "grinning face with smiling eyes")
    }

    @Test func keepsTheNewestRecentEmojiFirst() {
        var settings = EmojiSettings()
        for emoji in ["😀", "👍", "😀"] + (1...20).map(String.init) {
            settings.use(emoji)
        }

        #expect(settings.recent.count == EmojiSettings.recentLimit)
        #expect(settings.recent.first == "20")
        #expect(!settings.recent.contains("👍"))
    }
}
