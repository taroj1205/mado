import Foundation
import IOKit.hid
import IOKit.hidsystem

struct KeyMappings {
    typealias Mapping = [[String: AnyHashable]]

    static let key = kIOHIDUserKeyUsageMapKey
    static let capsLock = usage(kHIDUsage_KeyboardCapsLock)
    private static let pageShift = 32

    private(set) var originals: [UInt64: Mapping] = [:]

    static func usage(_ usage: Int) -> UInt64 {
        UInt64(kHIDPage_KeyboardOrKeypad) << pageShift | UInt64(usage)
    }

    static func merged(_ mapping: Mapping, capsLockTo usage: UInt64) -> Mapping {
        mapping.filter { $0[kIOHIDKeyboardModifierMappingSrcKey] as? UInt64 != capsLock } + [
            [
                kIOHIDKeyboardModifierMappingSrcKey: capsLock,
                kIOHIDKeyboardModifierMappingDstKey: usage,
            ]
        ]
    }

    static func restoreArguments(
        matching: [String: Any], original: Mapping
    ) -> (matching: String, mapping: String)? {
        guard
            let matchingJSON = try? JSONSerialization.data(withJSONObject: matching),
            let mappingJSON = try? JSONSerialization.data(withJSONObject: [key: original]),
            let matchingText = String(bytes: matchingJSON, encoding: .utf8),
            let mappingText = String(bytes: mappingJSON, encoding: .utf8)
        else {
            return nil
        }
        return (matchingText, mappingText)
    }

    mutating func sync(
        _ current: [UInt64: Mapping], remapping: Set<UInt64>, to usage: UInt64
    ) -> [UInt64: Mapping] {
        originals = originals.filter { current[$0.key] != nil }
        var writes: [UInt64: Mapping] = [:]
        for (id, mapping) in current {
            if remapping.contains(id) {
                let original = originals[id] ?? mapping
                originals[id] = original
                let target = Self.merged(original, capsLockTo: usage)
                if target != mapping {
                    writes[id] = target
                }
            } else if let original = originals.removeValue(forKey: id) {
                writes[id] = original
            }
        }
        return writes
    }

    mutating func restore() -> [UInt64: Mapping] {
        defer { originals = [:] }
        return originals
    }
}
