import AppCore
import Foundation
import Testing

@testable import InputKit

@Suite struct TapAssignmentsTests {
    private static let usSource = InputTarget.source(id: "com.apple.keylayout.US")

    private func assignments() -> TapAssignments {
        TapAssignments(inputSources: InputSourceSettings(), bindings: ModifierBindings())
    }

    @Test func showsTheDefaultEisuAndKanaTaps() {
        let all = assignments()

        #expect(all.action(for: .init(.leftCommand)) == .inputSource(target: .english))
        #expect(all.action(for: .init(.rightCommand)) == .inputSource(target: .japanese))
        #expect(all.action(for: .init(.leftShift)) == nil)
    }

    @Test func keepsAnInputSourceOnASingleTapWhereTheInputSourcesTabShowsIt() {
        var all = assignments()
        all.bind(.inputSource(target: .next), to: .init(.rightOption))

        #expect(all.inputSources.hotKey(for: .next) == .modifierTap(.rightOption))
        #expect(all.bindings.entries.isEmpty)
    }

    @Test func anAppReplacesTheEisuTapWithoutLeavingItBehind() {
        var all = assignments()
        all.bind(.item(id: "/Applications/Safari.app"), to: .init(.leftCommand))

        #expect(all.inputSources.hotKey(for: .english) == nil)
        #expect(all.action(for: .init(.leftCommand)) == .item(id: "/Applications/Safari.app"))
        #expect(all.entries.filter { $0.tap == .init(.leftCommand) }.count == 1)
    }

    @Test func aTargetAlreadyOnAKeyCanTakeAnotherTapWithoutMoving() {
        var all = assignments()
        all.bind(.inputSource(target: .english), to: .init(.rightOption))

        #expect(all.action(for: .init(.leftCommand)) == .inputSource(target: .english))
        #expect(all.action(for: .init(.rightOption)) == .inputSource(target: .english))
        #expect(all.inputSources.hotKey(for: .english) == .modifierTap(.leftCommand))
    }

    @Test func clearingATapRemovesItFromWhereverItLives() {
        var all = assignments()
        all.bind(.item(id: "mado.settings"), to: .init(.leftShift, count: 2))
        all.bind(nil, to: .init(.leftShift, count: 2))
        all.bind(nil, to: .init(.leftCommand))

        #expect(all.action(for: .init(.leftShift, count: 2)) == nil)
        #expect(all.action(for: .init(.leftCommand)) == nil)
        #expect(all.action(for: .init(.rightCommand)) == .inputSource(target: .japanese))
    }

    @Test(arguments: [
        ModifierTap.Tap(.leftShift, count: 2), ModifierTap.Tap(.leftCommand, count: 3),
        ModifierTap.Tap(.leftShift, .rightShift), ModifierTap.Tap(.function),
    ])
    func keepsEveryOtherTapInTheNewBindings(_ tap: ModifierTap.Tap) {
        var all = assignments()
        all.bind(.inputSource(target: Self.usSource), to: tap)

        #expect(all.bindings.action(for: tap) == .inputSource(target: Self.usSource))
        #expect(all.inputSources == InputSourceSettings())
    }

    @Test func aSingleTapAndADoubleTapOfOneKeyAreSeparate() {
        var all = assignments()
        all.bind(.item(id: "a"), to: .init(.leftOption))
        all.bind(.item(id: "b"), to: .init(.leftOption, count: 2))

        #expect(all.action(for: .init(.leftOption)) == .item(id: "a"))
        #expect(all.action(for: .init(.leftOption, count: 2)) == .item(id: "b"))
    }
}
