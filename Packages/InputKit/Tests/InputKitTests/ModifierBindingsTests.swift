import Foundation
import Testing

@testable import InputKit

@Suite struct ModifierBindingsTests {
    @Test func startsEmptyWhenNothingIsSaved() throws {
        let bindings = try JSONDecoder().decode(ModifierBindings.self, from: Data("{}".utf8))

        #expect(bindings.entries.isEmpty)
    }

    @Test func roundTripsEveryKindOfTapAndTarget() throws {
        var bindings = ModifierBindings()
        bindings.bind(.item(id: "/Applications/Safari.app"), to: .init(.leftShift, count: 2))
        bindings.bind(.item(id: "mado.settings"), to: .init(.leftCommand, count: 3))
        bindings.bind(.inputSource(target: .english), to: .init(.leftShift, .rightShift))
        bindings.bind(
            .inputSource(target: .source(id: "com.apple.keylayout.US")), to: .init(.function))

        let data = try JSONEncoder().encode(bindings)

        #expect(try JSONDecoder().decode(ModifierBindings.self, from: data) == bindings)
    }

    @Test func writesAChordWithItsKeysInKeyboardOrder() throws {
        var bindings = ModifierBindings()
        bindings.bind(.item(id: "a"), to: .init(.rightShift, .leftShift))

        let data = try JSONEncoder().encode(bindings)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains(#""modifiers":["left_shift","right_shift"]"#))
    }

    @Test func rebindingATapKeepsItInPlace() {
        var bindings = ModifierBindings()
        bindings.bind(.item(id: "a"), to: .init(.leftShift))
        bindings.bind(.item(id: "b"), to: .init(.leftOption))
        bindings.bind(.item(id: "c"), to: .init(.leftShift))

        #expect(bindings.entries.map(\.action) == [.item(id: "c"), .item(id: "b")])
    }

    @Test func dropsASavedTapWithoutAKeyOrACount() throws {
        let json = """
            {"taps":[
            {"modifiers":[],"count":1,"action":{"item":{"id":"a"}}},
            {"modifiers":["left_shift"],"count":0,"action":{"item":{"id":"b"}}},
            {"modifiers":["left_shift"],"count":2,"action":{"item":{"id":"c"}}}]}
            """

        let bindings = try JSONDecoder().decode(ModifierBindings.self, from: Data(json.utf8))

        #expect(bindings.entries.map(\.action) == [.item(id: "c")])
    }
}
