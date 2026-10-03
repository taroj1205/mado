import Foundation
import Testing

@testable import InputKit

@Suite struct AppInputSourcesTests {
    private static let terminal = "com.apple.Terminal"
    private static let messages = "com.apple.MobileSMS"
    private static let safari = "com.apple.Safari"
    private static let abc = "com.apple.keylayout.ABC"
    private static let hiragana = "com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese"

    private static var settings: AppInputSources {
        var value = AppInputSources()
        value.apps = [terminal: .source(id: abc), messages: .lastUsed]
        return value
    }

    @Test func anAppWithASourceSwitchesToIt() {
        var memory = AppInputSources.Memory(frontmost: nil)

        #expect(
            memory.activate(Self.terminal, leaving: Self.hiragana, with: Self.settings) == Self.abc)
    }

    @Test func anAppNotInTheListLeavesTheSourceAlone() {
        var memory = AppInputSources.Memory(frontmost: nil)

        #expect(memory.activate(Self.safari, leaving: Self.abc, with: Self.settings) == nil)
        #expect(memory.activate(nil, leaving: Self.abc, with: Self.settings) == nil)
    }

    @Test func lastUsedRestoresTheSourceTheAppWasLeftIn() {
        var memory = AppInputSources.Memory(frontmost: nil)

        #expect(memory.activate(Self.messages, leaving: Self.abc, with: Self.settings) == nil)
        #expect(memory.activate(Self.safari, leaving: Self.hiragana, with: Self.settings) == nil)
        #expect(
            memory.activate(Self.messages, leaving: Self.abc, with: Self.settings) == Self.hiragana)
    }

    @Test func theAppInFrontAtStartIsRememberedWhenLeft() {
        var memory = AppInputSources.Memory(frontmost: Self.messages)

        #expect(memory.activate(Self.safari, leaving: Self.hiragana, with: Self.settings) == nil)
        #expect(
            memory.activate(Self.messages, leaving: Self.abc, with: Self.settings) == Self.hiragana)
    }

    @Test func onlyLastUsedAppsAreRemembered() {
        var settings = Self.settings
        var memory = AppInputSources.Memory(frontmost: nil)
        _ = memory.activate(Self.safari, leaving: Self.abc, with: settings)
        _ = memory.activate(Self.messages, leaving: Self.hiragana, with: settings)

        settings.apps[Self.safari] = .lastUsed
        #expect(memory.activate(Self.safari, leaving: Self.abc, with: settings) == nil)
    }

    @Test func choicesSurviveARoundTrip() throws {
        let data = try JSONEncoder().encode(Self.settings)

        #expect(try JSONDecoder().decode(AppInputSources.self, from: data) == Self.settings)
    }
}
