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

    static func capsLockEntry(to usage: UInt64) -> Mapping {
        [
            [
                kIOHIDKeyboardModifierMappingSrcKey: capsLock,
                kIOHIDKeyboardModifierMappingDstKey: usage,
            ]
        ]
    }

    static func replacingCapsLock(in mapping: Mapping, with entries: Mapping) -> Mapping {
        let index = mapping.firstIndex(where: isCapsLock) ?? mapping.endIndex
        return mapping[..<index] + entries + mapping[index...].filter { !isCapsLock($0) }
    }

    static func restoreArguments(
        matching: [String: Any], mapping: Mapping
    ) -> (matching: String, mapping: String)? {
        guard
            let matchingJSON = try? JSONSerialization.data(
                withJSONObject: matching, options: .sortedKeys),
            let mappingJSON = try? JSONSerialization.data(
                withJSONObject: [key: mapping], options: .sortedKeys),
            let matchingText = String(bytes: matchingJSON, encoding: .utf8),
            let mappingText = String(bytes: mappingJSON, encoding: .utf8)
        else {
            return nil
        }
        return (matchingText, mappingText)
    }

    private static func isCapsLock(_ entry: [String: AnyHashable]) -> Bool {
        entry[kIOHIDKeyboardModifierMappingSrcKey] as? UInt64 == capsLock
    }

    mutating func sync(
        _ current: [UInt64: Mapping], remapping: Set<UInt64>, to usage: UInt64
    ) -> [UInt64: Mapping] {
        originals = originals.filter { current[$0.key] != nil }
        var writes: [UInt64: Mapping] = [:]
        for (id, mapping) in current {
            if remapping.contains(id) {
                originals[id] = originals[id] ?? mapping.filter(Self.isCapsLock)
                let target = Self.replacingCapsLock(
                    in: mapping, with: Self.capsLockEntry(to: usage))
                if target != mapping {
                    writes[id] = target
                }
            } else if let original = originals.removeValue(forKey: id) {
                writes[id] = Self.replacingCapsLock(in: mapping, with: original)
            }
        }
        return writes
    }

    func restores(from current: [UInt64: Mapping]) -> [UInt64: Mapping] {
        originals.reduce(into: [:]) { restores, original in
            guard let mapping = current[original.key] else { return }
            restores[original.key] = Self.replacingCapsLock(in: mapping, with: original.value)
        }
    }

    mutating func restore(from current: [UInt64: Mapping]) -> [UInt64: Mapping] {
        defer { originals = [:] }
        return restores(from: current)
    }
}
