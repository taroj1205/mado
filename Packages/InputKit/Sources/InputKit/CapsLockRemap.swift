public import Foundation
import IOKit.hidsystem

public enum CapsLockRemap: String, Codable, CaseIterable, Sendable {
    case capsLock = "caps_lock"
    case control = "control"
    case escape = "escape"
    case hyper = "hyper"

    public typealias Mapping = [[String: UInt64]]

    public struct System {
        public static var hid: Self {
            Self(
                read: {
                    let client = IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault)
                    guard let value = IOHIDEventSystemClientCopyProperty(client, key as CFString)
                    else {
                        return []
                    }
                    return value as? Mapping
                },
                write: { mapping in
                    let client = IOHIDEventSystemClientCreateSimpleClient(kCFAllocatorDefault)
                    return IOHIDEventSystemClientSetProperty(
                        client, key as CFString, mapping as CFArray)
                },
                turnOffCapsLock: {
                    let service = unsafe IOServiceGetMatchingService(
                        kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
                    defer { IOObjectRelease(service) }
                    var connect: io_connect_t = 0
                    let opened = unsafe IOServiceOpen(
                        service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connect)
                    guard opened == KERN_SUCCESS else { return }
                    defer { IOServiceClose(connect) }
                    IOHIDSetModifierLockState(connect, Int32(kIOHIDCapsLockState), false)
                })
        }

        private static let key = kIOHIDUserKeyUsageMapKey

        let read: @MainActor () -> Mapping?
        let write: @MainActor (Mapping) -> Bool
        let turnOffCapsLock: @MainActor () -> Void

        init(
            read: @escaping @MainActor () -> Mapping?,
            write: @escaping @MainActor (Mapping) -> Bool,
            turnOffCapsLock: @escaping @MainActor () -> Void
        ) {
            self.read = read
            self.write = write
            self.turnOffCapsLock = turnOffCapsLock
        }
    }

    private static let sourceKey = kIOHIDKeyboardModifierMappingSrcKey
    private static let destinationKey = kIOHIDKeyboardModifierMappingDstKey
    private static let originalKey = "MadoCapsLockOriginal"
    private static let capsLockUsage: UInt64 = 0x7_0000_0039
    private static let leftControlUsage: UInt64 = 0x7_0000_00E0
    private static let escapeUsage: UInt64 = 0x7_0000_0029
    private static let f18Usage: UInt64 = 0x7_0000_006D

    private var usage: UInt64? {
        switch self {
        case .capsLock: nil
        case .control: Self.leftControlUsage
        case .escape: Self.escapeUsage
        case .hyper: Self.f18Usage
        }
    }

    @MainActor
    public static func restore(system: System = .hid, defaults: UserDefaults = .standard) -> Bool {
        guard let original = defaults.array(forKey: originalKey) as? Mapping else {
            return true
        }
        guard let current = system.read(), system.write(withoutCapsLock(current) + original)
        else {
            return false
        }
        defaults.removeObject(forKey: originalKey)
        return true
    }

    private static func isCapsLock(_ entry: [String: UInt64]) -> Bool {
        entry[sourceKey] == capsLockUsage
    }

    private static func withoutCapsLock(_ mapping: Mapping) -> Mapping {
        mapping.filter { !isCapsLock($0) }
    }

    @MainActor
    public func apply(system: System = .hid, defaults: UserDefaults = .standard) -> Bool {
        guard let usage else {
            return Self.restore(system: system, defaults: defaults)
        }
        guard let current = system.read() else {
            return false
        }
        let saving = defaults.array(forKey: Self.originalKey) == nil
        if saving {
            defaults.set(current.filter(Self.isCapsLock), forKey: Self.originalKey)
        }
        let entry = [Self.sourceKey: Self.capsLockUsage, Self.destinationKey: usage]
        guard system.write(Self.withoutCapsLock(current) + [entry]) else {
            if saving {
                defaults.removeObject(forKey: Self.originalKey)
            }
            return false
        }
        system.turnOffCapsLock()
        return true
    }
}
