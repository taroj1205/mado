import Foundation
import Testing

@testable import InputKit

@MainActor
@Suite struct CapsLockRemapTests {
    @MainActor
    final class FakeHID {
        var mapping: CapsLockRemap.Mapping?
        var readable = true
        var writable = true
        var writes = 0
        var capsLockTurnedOff = 0
        private let suite = "CapsLockRemapTests-\(UUID())"
        private let defaults: UserDefaults

        private var system: CapsLockRemap.System {
            CapsLockRemap.System(
                read: { [self] in readable ? mapping : nil },
                write: { [self] new in
                    guard writable else { return false }
                    writes += 1
                    mapping = new
                    return true
                },
                turnOffCapsLock: { [self] in capsLockTurnedOff += 1 })
        }

        init(_ mapping: CapsLockRemap.Mapping) throws {
            self.mapping = mapping
            defaults = try #require(UserDefaults(suiteName: suite))
        }

        func apply(_ remap: CapsLockRemap) -> Bool {
            remap.apply(system: system, defaults: defaults)
        }

        func restore() -> Bool {
            CapsLockRemap.restore(system: system, defaults: defaults)
        }

        isolated deinit {
            defaults.removePersistentDomain(forName: suite)
        }
    }

    nonisolated private static let capsLock: UInt64 = 0x7_0000_0039
    nonisolated private static let control: UInt64 = 0x7_0000_00E0
    nonisolated private static let escape: UInt64 = 0x7_0000_0029
    nonisolated private static let f18: UInt64 = 0x7_0000_006D
    nonisolated private static let rightOption: UInt64 = 0x7_0000_00E6
    nonisolated private static let rightCommand: UInt64 = 0x7_0000_00E7

    private static func entry(_ source: UInt64, _ destination: UInt64) -> [String: UInt64] {
        ["HIDKeyboardModifierMappingSrc": source, "HIDKeyboardModifierMappingDst": destination]
    }

    @Test(arguments: [
        (CapsLockRemap.control, control), (.escape, escape), (.hyper, f18),
    ])
    func applyingMapsCapsLock(_ remap: CapsLockRemap, _ destination: UInt64) throws {
        let hid = try FakeHID([])
        #expect(hid.apply(remap))
        #expect(hid.mapping == [Self.entry(Self.capsLock, destination)])
        #expect(hid.capsLockTurnedOff == 1)
    }

    @Test func restoringLeavesAnEmptyMappingEmpty() throws {
        let hid = try FakeHID([])
        _ = hid.apply(.hyper)
        #expect(hid.restore())
        #expect(hid.mapping?.isEmpty == true)
    }

    @Test func otherKeysAreKeptAndTheirOwnCapsLockMappingComesBack() throws {
        let other = Self.entry(Self.rightOption, Self.rightCommand)
        let theirs = Self.entry(Self.capsLock, Self.escape)
        let hid = try FakeHID([other, theirs])
        _ = hid.apply(.control)
        #expect(hid.mapping == [other, Self.entry(Self.capsLock, Self.control)])

        let added = Self.entry(Self.rightCommand, Self.rightOption)
        hid.mapping?.append(added)
        _ = hid.restore()
        #expect(hid.mapping == [other, added, theirs])
    }

    @Test func aLeftoverFromACrashIsNotTakenAsTheOriginal() throws {
        let hid = try FakeHID([])
        _ = hid.apply(.hyper)
        _ = hid.apply(.control)
        _ = hid.restore()
        #expect(hid.mapping?.isEmpty == true)
    }

    @Test func restoringTwiceWritesOnce() throws {
        let hid = try FakeHID([])
        _ = hid.apply(.escape)
        _ = hid.restore()
        #expect(hid.restore())
        #expect(hid.writes == 2)
    }

    @Test func capsLockRestores() throws {
        let hid = try FakeHID([])
        _ = hid.apply(.control)
        #expect(hid.apply(.capsLock))
        #expect(hid.mapping?.isEmpty == true)
        #expect(hid.capsLockTurnedOff == 1)
    }

    @Test func capsLockTouchesNothingWhenNothingWasApplied() throws {
        let hid = try FakeHID([Self.entry(Self.capsLock, Self.escape)])
        #expect(hid.apply(.capsLock))
        #expect(hid.writes == 0)
    }

    @Test func aFailedWriteForgetsTheOriginal() throws {
        let hid = try FakeHID([Self.entry(Self.capsLock, Self.escape)])
        hid.writable = false
        #expect(!hid.apply(.control))
        #expect(hid.capsLockTurnedOff == 0)
        hid.writable = true
        hid.mapping = []
        #expect(hid.restore())
        #expect(hid.writes == 0)
    }

    @Test func anUnreadableMappingIsLeftAlone() throws {
        let hid = try FakeHID([])
        hid.readable = false
        #expect(!hid.apply(.control))
        #expect(hid.writes == 0)
    }

    @Test func aFailedRestoreKeepsTheOriginalForNextTime() throws {
        let theirs = Self.entry(Self.capsLock, Self.escape)
        let hid = try FakeHID([theirs])
        _ = hid.apply(.hyper)
        hid.writable = false
        #expect(!hid.restore())
        hid.writable = true
        #expect(hid.restore())
        #expect(hid.mapping == [theirs])
    }
}
