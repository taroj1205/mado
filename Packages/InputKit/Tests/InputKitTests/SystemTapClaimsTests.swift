import Testing

@testable import InputKit

@Suite struct SystemTapClaimsTests {
    private let fnTap = ModifierTap.Tap(.function)

    @Test func warnsAboutTheEmojiPickerWhenMacOSHasNotBeenToldOtherwise() {
        #expect(SystemTapClaims.use(of: fnTap, fnUsage: nil) == "the emoji picker")
        #expect(SystemTapClaims.use(of: fnTap, fnUsage: 2) == "the emoji picker")
    }

    @Test func warnsAboutInputSourcesWhenGlobeSwitchesThem() {
        #expect(SystemTapClaims.use(of: fnTap, fnUsage: 1) == "switching input sources")
    }

    @Test func staysQuietWhenGlobeDoesNothing() {
        #expect(SystemTapClaims.use(of: fnTap, fnUsage: 0) == nil)
    }

    @Test func dictationUsesTwoTapsOfFn() {
        #expect(SystemTapClaims.use(of: .init(.function, count: 2), fnUsage: 3) == "dictation")
        #expect(SystemTapClaims.use(of: fnTap, fnUsage: 3) == nil)
        #expect(SystemTapClaims.use(of: .init(.function, count: 2), fnUsage: 2) == nil)
    }

    @Test func leavesEveryOtherKeyAlone() {
        #expect(SystemTapClaims.use(of: .init(.leftCommand), fnUsage: nil) == nil)
        #expect(SystemTapClaims.use(of: .init(.function, .leftShift), fnUsage: nil) == nil)
    }
}
