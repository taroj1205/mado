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

    private static func makeSwitch(
        front: String?, _ sources: Sources, memory: AppInputSwitch.Memory = .init()
    ) -> AppInputSwitch {
        AppInputSwitch(
            front: front, current: { sources.current },
            select: { id in
                sources.selected.append(id)
                sources.current = id
            },
            settle: .zero, memory: memory)
    }

    private static func activate(_ app: String?, on switcher: AppInputSwitch) async {
        switcher.activated(app, apps: apps)
        await switcher.pending?.value
    }

    @Test func selectsTheSourceSetForTheAppThatBecomesActive() async {
        let sources = Sources(current: "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese")
        let switcher = Self.makeSwitch(front: "com.apple.Safari", sources)

        await Self.activate("com.apple.Terminal", on: switcher)
        await Self.activate("jp.naver.line.mac", on: switcher)

        #expect(
            sources.selected == [
                "com.apple.keylayout.ABC", "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese",
            ])
    }

    @Test func selectsOnlyAfterTheActivationSettles() async {
        let sources = Sources(current: "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese")
        let switcher = Self.makeSwitch(front: "com.apple.Safari", sources)

        switcher.activated("com.apple.Terminal", apps: Self.apps)
        #expect(sources.selected.isEmpty)
        await switcher.pending?.value

        #expect(sources.selected == ["com.apple.keylayout.ABC"])
    }

    @Test func leavingBeforeTheActivationSettlesCancelsTheSwitch() async {
        let sources = Sources(current: "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese")
        let switcher = Self.makeSwitch(front: "com.apple.Safari", sources)

        switcher.activated("com.apple.Terminal", apps: Self.apps)
        let cancelled = switcher.pending
        await Self.activate("com.apple.Safari", on: switcher)
        await cancelled?.value

        #expect(sources.selected.isEmpty)
    }

    @Test func leavesTheSourceAloneForAppsWithoutADefault() async {
        let sources = Sources(current: "com.apple.keylayout.ABC")
        let switcher = Self.makeSwitch(front: "com.apple.Terminal", sources)

        await Self.activate("com.apple.Safari", on: switcher)
        await Self.activate(nil, on: switcher)

        #expect(sources.selected.isEmpty)
    }

    @Test func lastUsedRestoresTheSourceTheAppWasLeftWith() async {
        let sources = Sources(current: "com.apple.keylayout.ABC")
        let switcher = Self.makeSwitch(front: "com.apple.MobileSMS", sources)
        sources.current = "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese"

        await Self.activate("com.apple.Terminal", on: switcher)
        await Self.activate("com.apple.MobileSMS", on: switcher)

        #expect(
            sources.selected == [
                "com.apple.keylayout.ABC", "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese",
            ])
    }

    @Test func lastUsedOutlivesASwitchStoppedInTheApp() async {
        let sources = Sources(current: "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese")
        let memory = AppInputSwitch.Memory()
        let before = Self.makeSwitch(front: "com.apple.MobileSMS", sources, memory: memory)
        await Self.activate(nil, on: before)

        let after = Self.makeSwitch(front: "com.apple.Safari", sources, memory: memory)
        sources.current = "com.apple.keylayout.ABC"
        await Self.activate("com.apple.MobileSMS", on: after)

        #expect(sources.selected == ["com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese"])
    }

    @Test func aSwitchStoppedBeforeItsSelectionLandsKeepsTheRememberedSource() async {
        let japanese = "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese"
        let sources = Sources(current: japanese)
        let memory = AppInputSwitch.Memory()
        let learned = Self.makeSwitch(front: "com.apple.MobileSMS", sources, memory: memory)
        await Self.activate("com.apple.Safari", on: learned)
        sources.current = "com.apple.keylayout.ABC"

        let stopped = Self.makeSwitch(front: "com.apple.Safari", sources, memory: memory)
        stopped.activated("com.apple.MobileSMS", apps: Self.apps)
        stopped.activated(nil, apps: Self.apps)
        let resumed = Self.makeSwitch(front: "com.apple.Safari", sources, memory: memory)
        await Self.activate("com.apple.MobileSMS", on: resumed)

        #expect(sources.selected == [japanese])
    }

    @Test func startingInAnAppSetsItsFixedOrRememberedSource() async {
        let japanese = "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese"
        let sources = Sources(current: japanese)
        let memory = AppInputSwitch.Memory()
        let learned = Self.makeSwitch(front: "com.apple.MobileSMS", sources, memory: memory)
        await Self.activate("com.apple.Terminal", on: learned)

        let resumed = Self.makeSwitch(front: nil, sources, memory: memory)
        await Self.activate("com.apple.MobileSMS", on: resumed)
        let started = Self.makeSwitch(front: nil, sources, memory: memory)
        await Self.activate("com.apple.Terminal", on: started)

        #expect(
            sources.selected == [
                "com.apple.keylayout.ABC", japanese, "com.apple.keylayout.ABC",
            ])
    }

    @Test func lastUsedChangesNothingUntilTheAppHasBeenLeft() async {
        let sources = Sources(current: "com.apple.keylayout.ABC")
        let switcher = Self.makeSwitch(front: "com.apple.Safari", sources)

        await Self.activate("com.apple.MobileSMS", on: switcher)

        #expect(sources.selected.isEmpty)
    }
}
