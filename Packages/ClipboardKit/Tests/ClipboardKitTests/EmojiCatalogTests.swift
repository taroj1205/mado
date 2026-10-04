import Testing

@testable import ClipboardKit

@Suite struct EmojiCatalogTests {
    private static let data = """
        # comment
        @Smileys & Emotion
        😄\tgrinning face with smiling eyes\thappy|laugh|smile|笑顔\t
        😍\tsmiling face with heart-eyes\tlove|目がハート\t
        @People & Body
        👍\tthumbs up\t+1|good|hand\t0
        ☝️\tindex pointing up\tfinger\t0
        🧑‍💻\ttechnologist\tcoder\t0
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
        #expect(catalog.search("笑顔").map(\.character) == ["😄"])
        #expect(catalog.search("ハート").map(\.character) == ["😍"])
        #expect(catalog.search("smile 笑").map(\.character) == ["😄"])
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
        #expect(bundled.search("flag canada").first?.character == "🇨🇦")
        #expect(bundled.search("笑う").prefix(8).map(\.character).contains("😂"))
        #expect(bundled.emoji("1️⃣")?.shortcode == ":keycap_1:")
        #expect(bundled.emoji("👨‍🦰")?.toned(.medium) == "👨🏽‍🦰")
        #expect(bundled.emoji("🧑‍🤝‍🧑")?.toned(.dark) == "🧑🏿‍🤝‍🧑🏿")
        let kiss = "\u{1F469}\u{200D}\u{2764}\u{FE0F}\u{200D}\u{1F48B}\u{200D}\u{1F468}"
        let lightKiss = "\u{1F469}\u{1F3FB}\u{200D}\u{2764}\u{FE0F}\u{200D}\u{1F48B}"
        #expect(bundled.emoji(kiss)?.toned(.light) == lightKiss + "\u{200D}\u{1F468}\u{1F3FB}")
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
