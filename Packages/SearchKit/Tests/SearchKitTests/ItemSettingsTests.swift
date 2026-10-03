import AppCore
import Foundation
import Testing

@testable import SearchKit

@Suite struct ItemSettingsTests {
    private let controlOptionT = Shortcut(keyCode: 17, modifiers: [.control, .option])

    private func rank(
        _ names: [String], by query: String, in settings: ItemSettings,
        bonus: @escaping (String) -> Int = { _ in 0 }
    ) -> [String] {
        settings.rank(names, by: query, bonus: bonus, id: \.self) { [Fuzzy.Key($0)] }
    }

    @Test func storesEachItemsAliasesHotkeyAndFavourite() {
        var settings = ItemSettings()
        settings["terminal"] = .init(aliases: ["t", "term"], hotkey: controlOptionT)
        settings["notes"] = .init(favourite: true)

        #expect(settings["terminal"] == .init(aliases: ["t", "term"], hotkey: controlOptionT))
        #expect(settings["notes"] == .init(favourite: true))
        #expect(settings["safari"] == .init())
        #expect(settings.owner(of: controlOptionT) == "terminal")
        #expect(settings.hotkeys == ["terminal": controlOptionT])
    }

    @Test func listsFavouritesInTheOrderTheyWereAdded() {
        var settings = ItemSettings()
        settings["notes"] = .init(favourite: true)
        settings["safari"] = .init(favourite: true)
        settings["notes"] = .init(aliases: ["n"], favourite: true)
        #expect(settings.favourites == ["notes", "safari"])

        settings["notes"] = .init()
        #expect(settings.favourites == ["safari"])
        #expect(
            settings
                == {
                    var only = ItemSettings()
                    only["safari"] = .init(favourite: true)
                    return only
                }())
    }

    @Test func anExactAliasRanksFirstAheadOfUsage() {
        var settings = ItemSettings()
        settings["Terminal"] = .init(aliases: ["t"])
        let names = ["TextEdit", "Terminal", "Tips"]
        let used = { (name: String) in name == "TextEdit" ? 40 : 0 }

        #expect(rank(names, by: "t", in: settings, bonus: used).first == "Terminal")
        #expect(rank(names, by: " T ", in: settings).first == "Terminal")
        #expect(rank(names, by: "te", in: settings, bonus: used).first == "TextEdit")
    }

    @Test func aliasesAlsoMatchLikeNames() {
        var settings = ItemSettings()
        settings["Adobe Photoshop"] = .init(aliases: ["ps", "写真"])
        let names = ["Pages", "Adobe Photoshop"]

        #expect(rank(names, by: "ps", in: settings) == ["Adobe Photoshop", "Pages"])
        #expect(rank(names, by: "写真", in: settings) == ["Adobe Photoshop"])
        #expect(settings.ids(withAlias: "").isEmpty)
        #expect(settings.ids(withAlias: "PS") == ["Adobe Photoshop"])
    }

    @Test func quickPeekIsKeptOnlyWhileTheItemHasAHotkey() {
        var settings = ItemSettings()
        settings["dictionary"] = .init(hotkey: controlOptionT, quickPeek: true)
        settings["calculator"] = .init(quickPeek: true)

        #expect(settings["dictionary"].quickPeek)
        #expect(!settings["calculator"].quickPeek)

        settings["dictionary"].hotkey = nil
        #expect(!settings["dictionary"].quickPeek)
        settings["dictionary"].hotkey = controlOptionT
        #expect(!settings["dictionary"].quickPeek)
    }

    @Test func settingsSavedBeforeQuickPeekStillLoad() throws {
        let saved = Data(
            #"{"aliases":{"terminal":["t"]},"favourites":["terminal"],"hotkeys":{}}"#.utf8)

        let decoded = try JSONDecoder().decode(ItemSettings.self, from: saved)

        #expect(decoded["terminal"] == .init(aliases: ["t"], favourite: true))
    }

    @Test func survivesAJSONRoundTrip() throws {
        var settings = ItemSettings()
        settings["terminal"] = .init(
            aliases: ["t"], hotkey: controlOptionT, favourite: true, quickPeek: true)

        let decoded = try JSONDecoder().decode(
            ItemSettings.self, from: JSONEncoder().encode(settings))

        #expect(decoded == settings)
    }
}
