import AppCore
import Foundation
import IOKit.hid
import Testing

@testable import InputKit

@Suite struct KeyMappingsTests {
    private static let builtIn: UInt64 = 1
    private static let external: UInt64 = 2
    private static let control = KeyMappings.usage(kHIDUsage_KeyboardLeftControl)
    private static let rightControl = KeyMappings.usage(kHIDUsage_KeyboardRightControl)
    private static let escape = KeyMappings.usage(kHIDUsage_KeyboardEscape)
    private static var swap: [String: AnyHashable] {
        pair(KeyMappings.usage(kHIDUsage_KeyboardA), KeyMappings.usage(kHIDUsage_KeyboardB))
    }
    private static var fKeys: [String: AnyHashable] {
        pair(KeyMappings.usage(kHIDUsage_KeyboardF20), KeyMappings.usage(kHIDUsage_KeyboardF19))
    }
    private static var rightControlGuard: KeyMappings.Mapping {
        [pair(rightControl, control)]
    }

    private static func pair(_ source: UInt64, _ destination: UInt64) -> [String: AnyHashable] {
        [
            "HIDKeyboardModifierMappingSrc": source,
            "HIDKeyboardModifierMappingDst": destination,
        ]
    }

    private static func toControl() -> KeyMappings {
        KeyMappings(remapped: [pair(KeyMappings.capsLock, control)], others: [])
    }

    private static func toRightControl() -> KeyMappings {
        KeyMappings(
            remapped: [pair(KeyMappings.capsLock, rightControl)] + rightControlGuard,
            others: rightControlGuard)
    }

    private static func capsLockOriginal(_ entries: KeyMappings.Mapping) -> KeyMappings.Original {
        KeyMappings.Original(sources: [KeyMappings.capsLock], entries: entries)
    }

    @Test func usagesUseTheKeyboardPageAsTN2450Describes() {
        #expect(KeyMappings.capsLock == 0x7_0000_0039)
        let usages = RemapSettings.CapsLock.allCases.map { capsLock in
            var settings = RemapSettings()
            settings.capsLock = capsLock
            return settings.usage
        }
        #expect(usages == [nil, 0x7_0000_00E0, 0x7_0000_0029, 0x7_0000_006D])
    }

    @Test(arguments: RemapSettings.TapAction.allCases)
    func controlIsRightControlOnlyWhileATapDoesSomething(_ action: RemapSettings.TapAction) {
        var settings = RemapSettings()
        settings.capsLock = .control
        settings.tapAction = action
        settings.tapShortcut = Shortcut(keyCode: 17, modifiers: .hyper)
        #expect(settings.usage == (action == .nothing ? 0x7_0000_00E0 : 0x7_0000_00E4))
    }

    @Test(arguments: RemapSettings.CapsLock.allCases, RemapSettings.TapAction.allCases)
    func onlyCapsLockSendsRightControlWhileItsTapDoesSomething(
        _ capsLock: RemapSettings.CapsLock, _ action: RemapSettings.TapAction
    ) {
        var settings = RemapSettings()
        settings.capsLock = capsLock
        settings.tapAction = action
        settings.tapShortcut = Shortcut(keyCode: 17, modifiers: .hyper)
        guard let usage = settings.usage else {
            #expect(settings.mappings == nil)
            return
        }
        let guarded = capsLock == .control && action != .nothing
        let others = guarded ? Self.rightControlGuard : []
        #expect(settings.mappings?.remapped == [Self.pair(KeyMappings.capsLock, usage)] + others)
        #expect(settings.mappings?.others == others)
    }

    @Test func aKeyboardLeftOutKeepsItsCapsLockAndLosesOnlyRightControl() {
        var mappings = Self.toRightControl()
        let user: KeyMappings.Mapping = [
            Self.swap, Self.pair(KeyMappings.capsLock, Self.escape),
            Self.pair(Self.rightControl, Self.escape),
        ]

        let writes = mappings.sync(
            [Self.builtIn: user, Self.external: user], remapping: [Self.builtIn])

        #expect(
            writes == [
                Self.builtIn: [
                    Self.swap, Self.pair(KeyMappings.capsLock, Self.rightControl),
                    Self.pair(Self.rightControl, Self.control),
                ],
                Self.external: [
                    Self.swap, Self.pair(KeyMappings.capsLock, Self.escape),
                    Self.pair(Self.rightControl, Self.control),
                ],
            ])
        #expect(mappings.restore(from: writes) == [Self.builtIn: user, Self.external: user])
    }

    @Test func aKeyboardThatFailedToSwitchKeepsWhatItHadBeforeMado() throws {
        var mappings = Self.toRightControl()
        let user: KeyMappings.Mapping = [Self.pair(KeyMappings.capsLock, Self.escape)]
        let first = mappings.sync([Self.external: user], remapping: [Self.external])
        let applied = try #require(first[Self.external])
        let earlier = mappings

        let writes = mappings.sync([Self.external: applied], remapping: [])
        mappings.keepOriginals(of: Set(writes.keys), from: earlier)

        #expect(writes == [Self.external: user + Self.rightControlGuard])
        #expect(mappings.restores(from: [Self.external: applied]) == [Self.external: user])
    }

    @Test func replacingKeepsOtherKeysAndSwapsTheCapsLockEntry() {
        let user: KeyMappings.Mapping = [Self.swap, Self.pair(KeyMappings.capsLock, Self.escape)]
        let replaced = KeyMappings.replacing(
            [KeyMappings.capsLock], in: user,
            with: [KeyMappings.entry(KeyMappings.capsLock, to: Self.control)])
        #expect(replaced == [Self.swap, Self.pair(KeyMappings.capsLock, Self.control)])
    }

    @Test func syncRemapsOnlyTheChosenKeyboards() {
        var mappings = Self.toControl()
        let writes = mappings.sync(
            [Self.builtIn: [], Self.external: [Self.swap]], remapping: [Self.builtIn])
        #expect(writes == [Self.builtIn: [Self.pair(KeyMappings.capsLock, Self.control)]])
        #expect(mappings.originals == [Self.builtIn: Self.capsLockOriginal([])])
    }

    @Test func restoreGivesBackTheCapsLockEntryFromBeforeMado() throws {
        var mappings = Self.toControl()
        let user: KeyMappings.Mapping = [Self.swap, Self.pair(KeyMappings.capsLock, Self.escape)]
        let writes = mappings.sync(
            [Self.builtIn: user], remapping: [Self.builtIn])
        #expect(
            writes == [Self.builtIn: [Self.swap, Self.pair(KeyMappings.capsLock, Self.control)]])
        let applied = try #require(writes[Self.builtIn])
        #expect(
            mappings.restore(from: [Self.builtIn: applied])
                == [Self.builtIn: [Self.swap, Self.pair(KeyMappings.capsLock, Self.escape)]])
        #expect(mappings.originals.isEmpty)
    }

    @Test func otherKeysChangedWhileRemappedAreKept() throws {
        var mappings = Self.toControl()
        let first = mappings.sync([Self.builtIn: []], remapping: [Self.builtIn])
        let changed = try #require(first[Self.builtIn]) + [Self.fKeys]

        let second = mappings.sync(
            [Self.builtIn: changed], remapping: [Self.builtIn])

        #expect(second.isEmpty)
        #expect(mappings.restores(from: [Self.builtIn: changed]) == [Self.builtIn: [Self.fKeys]])
        #expect(mappings.restore(from: [Self.builtIn: changed]) == [Self.builtIn: [Self.fKeys]])
    }

    @Test func aKeyboardTurnedOffKeepsKeysChangedWhileRemapped() throws {
        var mappings = Self.toControl()
        let first = mappings.sync(
            [Self.external: [Self.swap]], remapping: [Self.external])
        let changed = try #require(first[Self.external]) + [Self.fKeys]

        let writes = mappings.sync([Self.external: changed], remapping: [])

        #expect(writes == [Self.external: [Self.swap, Self.fKeys]])
    }

    @Test func aSecondSyncLeavesAnAppliedKeyboardAlone() {
        var mappings = Self.toControl()
        let first = mappings.sync([Self.builtIn: []], remapping: [Self.builtIn])
        let applied = first[Self.builtIn] ?? []
        let second = mappings.sync(
            [Self.builtIn: applied], remapping: [Self.builtIn])
        #expect(second.isEmpty)
        #expect(mappings.originals == [Self.builtIn: Self.capsLockOriginal([])])
    }

    @Test func aKeyboardTurnedOffGetsItsOwnMappingBack() {
        var mappings = Self.toControl()
        let first = mappings.sync(
            [Self.external: [Self.swap]], remapping: [Self.external])
        let applied = first[Self.external] ?? []
        let writes = mappings.sync([Self.external: applied], remapping: [])
        #expect(writes == [Self.external: [Self.swap]])
        #expect(mappings.originals.isEmpty)
    }

    @Test func aKeyboardThatFailedToGoBackIsTriedAgain() throws {
        var mappings = Self.toControl()
        let first = mappings.sync(
            [Self.external: [Self.swap]], remapping: [Self.external])
        let applied = try #require(first[Self.external])
        let earlier = mappings
        let writes = mappings.sync([Self.external: applied], remapping: [])

        mappings.keepOriginals(of: Set(writes.keys), from: earlier)

        #expect(mappings.restores(from: [Self.external: applied]) == [Self.external: [Self.swap]])
        #expect(
            mappings.sync([Self.external: applied], remapping: [])
                == [Self.external: [Self.swap]])
    }

    @Test func aDisconnectedKeyboardIsForgotten() {
        var mappings = Self.toControl()
        _ = mappings.sync(
            [Self.builtIn: [], Self.external: []], remapping: [Self.builtIn, Self.external])
        let writes = mappings.sync(
            [Self.builtIn: [Self.pair(KeyMappings.capsLock, Self.control)]],
            remapping: [Self.builtIn, Self.external])
        #expect(writes.isEmpty)
        #expect(mappings.originals == [Self.builtIn: Self.capsLockOriginal([])])
    }

    @Test func aNewKeyboardIsRemappedFromItsOwnMapping() {
        var mappings = Self.toControl()
        _ = mappings.sync([Self.builtIn: []], remapping: [Self.builtIn])
        let writes = mappings.sync(
            [
                Self.builtIn: [Self.pair(KeyMappings.capsLock, Self.control)],
                Self.external: [Self.swap],
            ],
            remapping: [Self.builtIn, Self.external])
        #expect(
            writes == [Self.external: [Self.swap, Self.pair(KeyMappings.capsLock, Self.control)]])
        #expect(
            mappings.originals == [
                Self.builtIn: Self.capsLockOriginal([]), Self.external: Self.capsLockOriginal([]),
            ])
    }

    @Test func theWatchdogGetsJSONThatHidutilAccepts() throws {
        let matching: [String: Any] = ["Product": "Keychron K3", "VendorID": 0x05AC]
        let arguments = try #require(
            KeyMappings.restoreArguments(matching: matching, mapping: [Self.swap]))
        let decodedMatching = try JSONSerialization.jsonObject(with: Data(arguments.matching.utf8))
        #expect(
            decodedMatching as? [String: AnyHashable]
                == ["Product": "Keychron K3", "VendorID": 0x05AC])
        let decodedMapping = try JSONSerialization.jsonObject(with: Data(arguments.mapping.utf8))
        #expect(decodedMapping as? [String: KeyMappings.Mapping] == ["UserKeyMapping": [Self.swap]])
    }

    @Test func aMappingReadBackFromTheSystemCountsAsApplied() throws {
        var mappings = Self.toControl()
        let first = mappings.sync(
            [Self.builtIn: [Self.swap]], remapping: [Self.builtIn])
        let applied = try #require(first[Self.builtIn])
        let readBack = try #require((applied as CFArray) as? KeyMappings.Mapping)
        let second = mappings.sync(
            [Self.builtIn: readBack], remapping: [Self.builtIn])
        #expect(second.isEmpty)
    }
}
