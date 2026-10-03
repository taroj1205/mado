import Testing

@testable import InputKit

@MainActor
@Suite struct AppInputSwitchTests {
    private final class Sources {
        var current: String?
        var selected: [String] = []

        init(current: String?) {
            self.current = current
        }
    }

    private static let apps: [String: AppInput] = [
        "com.apple.Terminal": .source(id: "com.apple.keylayout.ABC"),
        "jp.naver.line.mac": .source(id: "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese"),
        "com.apple.MobileSMS": .lastUsed,
    ]

    private static func makeSwitch(front: String?, _ sources: Sources) -> AppInputSwitch {
        AppInputSwitch(
            front: front, current: { sources.current },
            select: { id in
                sources.selected.append(id)
                sources.current = id
            })
    }

    @Test func selectsTheSourceSetForTheAppThatBecomesActive() {
        let sources = Sources(current: "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese")
        let switcher = Self.makeSwitch(front: "com.apple.Safari", sources)

        switcher.activated("com.apple.Terminal", apps: Self.apps)
        switcher.activated("jp.naver.line.mac", apps: Self.apps)

        #expect(
            sources.selected == [
                "com.apple.keylayout.ABC", "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese",
            ])
    }

    @Test func leavesTheSourceAloneForAppsWithoutADefault() {
        let sources = Sources(current: "com.apple.keylayout.ABC")
        let switcher = Self.makeSwitch(front: "com.apple.Terminal", sources)

        switcher.activated("com.apple.Safari", apps: Self.apps)
        switcher.activated(nil, apps: Self.apps)

        #expect(sources.selected.isEmpty)
    }

    @Test func lastUsedRestoresTheSourceTheAppWasLeftWith() {
        let sources = Sources(current: "com.apple.keylayout.ABC")
        let switcher = Self.makeSwitch(front: "com.apple.MobileSMS", sources)
        sources.current = "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese"

        switcher.activated("com.apple.Terminal", apps: Self.apps)
        switcher.activated("com.apple.MobileSMS", apps: Self.apps)

        #expect(
            sources.selected == [
                "com.apple.keylayout.ABC", "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese",
            ])
    }

    @Test func lastUsedChangesNothingUntilTheAppHasBeenLeft() {
        let sources = Sources(current: "com.apple.keylayout.ABC")
        let switcher = Self.makeSwitch(front: "com.apple.Safari", sources)

        switcher.activated("com.apple.MobileSMS", apps: Self.apps)

        #expect(sources.selected.isEmpty)
    }
}
