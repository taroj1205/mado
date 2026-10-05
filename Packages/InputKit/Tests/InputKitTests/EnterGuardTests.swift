import Carbon.HIToolbox
import CoreGraphics
import Testing

@testable import InputKit

@Suite struct EnterGuardTests {
    struct Keys {
        static let chat: pid_t = 100
        static let other: pid_t = 200

        var keys = EnterGuard()
        var isJapanese = false
        var guarded: Set<pid_t> = [chat]
        var app = chat

        mutating func type(_ keyCode: Int) {
            type(keyCode, flags: [])
        }

        mutating func type(_ keyCode: Int, flags: CGEventFlags) {
            #expect(press(keyCode, flags: flags) == .pass)
        }

        mutating func press(_ keyCode: Int) -> EnterGuard.Action {
            press(keyCode, flags: [])
        }

        mutating func press(_ keyCode: Int, flags: CGEventFlags) -> EnterGuard.Action {
            let composes = isJapanese
            let isGuarded = guarded.contains(app)
            return keys.handle(
                keyCode: Int64(keyCode), flags: flags, target: app, composes: { composes },
                isGuarded: { isGuarded })
        }
    }

    @Test func returnBecomesANewLineAndCommandReturnSends() {
        var keys = Keys()

        #expect(keys.press(kVK_Return) == .newLine)
        #expect(keys.press(kVK_ANSI_KeypadEnter, flags: .maskNumericPad) == .newLine)
        #expect(keys.press(kVK_Return, flags: .maskCommand) == .send)
        #expect(keys.press(kVK_Return, flags: .maskAlphaShift) == .newLine)
    }

    @Test func otherModifiersOnReturnPassThrough() {
        var keys = Keys()

        for flags: CGEventFlags in [
            .maskShift, .maskAlternate, .maskControl, [.maskCommand, .maskShift],
            [.maskShift, .maskControl, .maskAlternate, .maskCommand],
        ] {
            #expect(keys.press(kVK_Return, flags: flags) == .pass)
        }
    }

    @Test func appsOffTheListKeepTheirReturn() {
        var keys = Keys()

        keys.app = Keys.other

        #expect(keys.press(kVK_Return) == .pass)
        #expect(keys.press(kVK_Return, flags: .maskCommand) == .pass)
    }

    @Test func theReturnThatConfirmsAConversionIsLeftAlone() {
        var keys = Keys()
        keys.isJapanese = true
        keys.type(kVK_ANSI_K)
        keys.type(kVK_ANSI_A)
        keys.type(kVK_Space)

        #expect(keys.press(kVK_Return) == .pass)
        #expect(keys.press(kVK_Return) == .newLine)
    }

    @Test func commandReturnDuringAConversionIsLeftAloneToo() {
        var keys = Keys()
        keys.isJapanese = true
        keys.type(kVK_ANSI_A, flags: .maskShift)

        #expect(keys.press(kVK_Return, flags: .maskCommand) == .pass)
        #expect(keys.press(kVK_Return, flags: .maskCommand) == .send)
    }

    @Test func aConversionStaysOpenThroughEditingKeys() {
        var keys = Keys()
        keys.isJapanese = true
        keys.type(kVK_ANSI_A)
        for key in [kVK_Delete, kVK_Escape, kVK_LeftArrow, kVK_Tab, kVK_F7] {
            keys.type(key)
        }
        keys.type(kVK_ANSI_C, flags: .maskCommand)

        #expect(keys.press(kVK_Return) == .pass)
    }

    @Test func keysThatTypeNothingDoNotStartAConversion() {
        var keys = Keys()
        keys.isJapanese = true
        for key in [kVK_Space, kVK_Delete, kVK_Escape, kVK_DownArrow, kVK_JIS_Kana, kVK_F1] {
            keys.type(key)
        }
        keys.type(kVK_ANSI_V, flags: .maskCommand)
        keys.type(kVK_ANSI_J, flags: .maskControl)

        #expect(keys.press(kVK_Return) == .newLine)
    }

    @Test func typingInAnEnglishSourceStartsNoConversion() {
        var keys = Keys()
        keys.type(kVK_ANSI_K)
        keys.type(kVK_ANSI_A)

        #expect(keys.press(kVK_Return) == .newLine)
    }

    @Test func aConversionBelongsToTheAppItWasTypedIn() {
        var keys = Keys()
        keys.guarded = [Keys.chat, Keys.other]
        keys.isJapanese = true
        keys.app = Keys.other
        keys.type(kVK_ANSI_A)
        keys.app = Keys.chat

        #expect(keys.press(kVK_Return) == .newLine)

        keys.app = Keys.other

        #expect(keys.press(kVK_Return) == .pass)
    }

    @Test func switchingAwayEndsTheConversion() {
        var keys = Keys()
        keys.isJapanese = true
        keys.type(kVK_ANSI_A)
        keys.keys.activated(Keys.other)
        keys.keys.activated(Keys.chat)

        #expect(keys.press(kVK_Return) == .newLine)
    }

    @Test func aLateActivationOfTheSameAppKeepsItsConversion() {
        var keys = Keys()
        keys.isJapanese = true
        keys.type(kVK_ANSI_A)
        keys.keys.activated(Keys.chat)

        #expect(keys.press(kVK_Return) == .pass)
    }
}
