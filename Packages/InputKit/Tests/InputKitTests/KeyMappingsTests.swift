import Foundation
import IOKit.hid
import Testing

@testable import InputKit

@Suite struct KeyMappingsTests {
    private static let builtIn: UInt64 = 1
    private static let external: UInt64 = 2
    private static let control = KeyMappings.usage(kHIDUsage_KeyboardLeftControl)
    private static let escape = KeyMappings.usage(kHIDUsage_KeyboardEscape)
    private static var swap: [String: AnyHashable] {
        pair(KeyMappings.usage(kHIDUsage_KeyboardA), KeyMappings.usage(kHIDUsage_KeyboardB))
    }
    private static var fKeys: [String: AnyHashable] {
        pair(KeyMappings.usage(kHIDUsage_KeyboardF20), KeyMappings.usage(kHIDUsage_KeyboardF19))
    }

    private static func pair(_ source: UInt64, _ destination: UInt64) -> [String: AnyHashable] {
        [
            "HIDKeyboardModifierMappingSrc": source,
            "HIDKeyboardModifierMappingDst": destination,
        ]
    }

    @Test func usagesUseTheKeyboardPageAsTN2450Describes() {
        #expect(KeyMappings.capsLock == 0x7_0000_0039)
        #expect(RemapSettings.CapsLock.control.usage == 0x7_0000_00E4)
        #expect(RemapSettings.CapsLock.escape.usage == 0x7_0000_0029)
        #expect(RemapSettings.CapsLock.hyper.usage == 0x7_0000_006D)
        #expect(RemapSettings.CapsLock.capsLock.usage == nil)
    }

    @Test func replacingKeepsOtherKeysAndSwapsTheCapsLockEntry() {
        let user: KeyMappings.Mapping = [Self.swap, Self.pair(KeyMappings.capsLock, Self.escape)]
        let replaced = KeyMappings.replacingCapsLock(
            in: user, with: KeyMappings.capsLockEntry(to: Self.control))
        #expect(replaced == [Self.swap, Self.pair(KeyMappings.capsLock, Self.control)])
    }

    @Test func syncRemapsOnlyTheChosenKeyboards() {
        var mappings = KeyMappings()
        let writes = mappings.sync(
            [Self.builtIn: [], Self.external: [Self.swap]], remapping: [Self.builtIn],
            to: Self.control)
        #expect(writes == [Self.builtIn: [Self.pair(KeyMappings.capsLock, Self.control)]])
        #expect(mappings.originals == [Self.builtIn: []])
    }

    @Test func restoreGivesBackTheCapsLockEntryFromBeforeMado() throws {
        var mappings = KeyMappings()
        let user: KeyMappings.Mapping = [Self.swap, Self.pair(KeyMappings.capsLock, Self.escape)]
        let writes = mappings.sync(
            [Self.builtIn: user], remapping: [Self.builtIn], to: Self.control)
        #expect(
            writes == [Self.builtIn: [Self.swap, Self.pair(KeyMappings.capsLock, Self.control)]])
        let applied = try #require(writes[Self.builtIn])
        #expect(
            mappings.restore(from: [Self.builtIn: applied])
                == [Self.builtIn: [Self.swap, Self.pair(KeyMappings.capsLock, Self.escape)]])
        #expect(mappings.originals.isEmpty)
    }

    @Test func otherKeysChangedWhileRemappedAreKept() throws {
        var mappings = KeyMappings()
        let first = mappings.sync([Self.builtIn: []], remapping: [Self.builtIn], to: Self.control)
        let changed = try #require(first[Self.builtIn]) + [Self.fKeys]

        let second = mappings.sync(
            [Self.builtIn: changed], remapping: [Self.builtIn], to: Self.control)

        #expect(second.isEmpty)
        #expect(mappings.restores(from: [Self.builtIn: changed]) == [Self.builtIn: [Self.fKeys]])
        #expect(mappings.restore(from: [Self.builtIn: changed]) == [Self.builtIn: [Self.fKeys]])
    }

    @Test func aKeyboardTurnedOffKeepsKeysChangedWhileRemapped() throws {
        var mappings = KeyMappings()
        let first = mappings.sync(
            [Self.external: [Self.swap]], remapping: [Self.external], to: Self.control)
        let changed = try #require(first[Self.external]) + [Self.fKeys]

        let writes = mappings.sync([Self.external: changed], remapping: [], to: Self.control)

        #expect(writes == [Self.external: [Self.swap, Self.fKeys]])
    }

    @Test func aSecondSyncLeavesAnAppliedKeyboardAlone() {
        var mappings = KeyMappings()
        let first = mappings.sync([Self.builtIn: []], remapping: [Self.builtIn], to: Self.control)
        let applied = first[Self.builtIn] ?? []
        let second = mappings.sync(
            [Self.builtIn: applied], remapping: [Self.builtIn], to: Self.control)
        #expect(second.isEmpty)
        #expect(mappings.originals == [Self.builtIn: []])
    }

    @Test func aKeyboardTurnedOffGetsItsOwnMappingBack() {
        var mappings = KeyMappings()
        let first = mappings.sync(
            [Self.external: [Self.swap]], remapping: [Self.external], to: Self.control)
        let applied = first[Self.external] ?? []
        let writes = mappings.sync([Self.external: applied], remapping: [], to: Self.control)
        #expect(writes == [Self.external: [Self.swap]])
        #expect(mappings.originals.isEmpty)
    }

    @Test func aKeyboardThatFailedToGoBackIsTriedAgain() throws {
        var mappings = KeyMappings()
        let first = mappings.sync(
            [Self.external: [Self.swap]], remapping: [Self.external], to: Self.control)
        let applied = try #require(first[Self.external])
        let earlier = mappings
        let writes = mappings.sync([Self.external: applied], remapping: [], to: Self.control)

        mappings.keepOriginals(of: Set(writes.keys), from: earlier)

        #expect(mappings.restores(from: [Self.external: applied]) == [Self.external: [Self.swap]])
        #expect(
            mappings.sync([Self.external: applied], remapping: [], to: Self.control)
                == [Self.external: [Self.swap]])
    }

    @Test func aDisconnectedKeyboardIsForgotten() {
        var mappings = KeyMappings()
        _ = mappings.sync(
            [Self.builtIn: [], Self.external: []], remapping: [Self.builtIn, Self.external],
            to: Self.control)
        let writes = mappings.sync(
            [Self.builtIn: [Self.pair(KeyMappings.capsLock, Self.control)]],
            remapping: [Self.builtIn, Self.external], to: Self.control)
        #expect(writes.isEmpty)
        #expect(mappings.originals == [Self.builtIn: []])
    }

    @Test func aNewKeyboardIsRemappedFromItsOwnMapping() {
        var mappings = KeyMappings()
        _ = mappings.sync([Self.builtIn: []], remapping: [Self.builtIn], to: Self.control)
        let writes = mappings.sync(
            [
                Self.builtIn: [Self.pair(KeyMappings.capsLock, Self.control)],
                Self.external: [Self.swap],
            ],
            remapping: [Self.builtIn, Self.external], to: Self.control)
        #expect(
            writes == [Self.external: [Self.swap, Self.pair(KeyMappings.capsLock, Self.control)]])
        #expect(mappings.originals == [Self.builtIn: [], Self.external: []])
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
        var mappings = KeyMappings()
        let first = mappings.sync(
            [Self.builtIn: [Self.swap]], remapping: [Self.builtIn], to: Self.control)
        let applied = try #require(first[Self.builtIn])
        let readBack = try #require((applied as CFArray) as? KeyMappings.Mapping)
        let second = mappings.sync(
            [Self.builtIn: readBack], remapping: [Self.builtIn], to: Self.control)
        #expect(second.isEmpty)
    }
}
