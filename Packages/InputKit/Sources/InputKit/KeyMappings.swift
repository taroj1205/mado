import Foundation
import IOKit.hid
import IOKit.hidsystem

struct KeyMappings {
    typealias Entry = [String: AnyHashable]
    typealias Mapping = [Entry]

    struct Original: Equatable {
        let sources: Set<UInt64>
        let entries: Mapping
    }

    static let key = kIOHIDUserKeyUsageMapKey
    static let capsLock = usage(kHIDUsage_KeyboardCapsLock)
    private static let pageShift = 32

    let remapped: Mapping
    let others: Mapping
    private(set) var originals: [UInt64: Original] = [:]

    init(remapped: Mapping, others: Mapping) {
        self.remapped = remapped
        self.others = others
    }

    static func usage(_ usage: Int) -> UInt64 {
        UInt64(kHIDPage_KeyboardOrKeypad) << pageShift | UInt64(usage)
    }

    static func entry(_ source: UInt64, to destination: UInt64) -> Entry {
        [
            kIOHIDKeyboardModifierMappingSrcKey: source,
            kIOHIDKeyboardModifierMappingDstKey: destination,
        ]
    }

    static func replacing(
        _ sources: Set<UInt64>, in mapping: Mapping, with entries: Mapping
    ) -> Mapping {
        let index = mapping.firstIndex { isOwned($0, by: sources) } ?? mapping.endIndex
        return mapping[..<index] + entries + mapping[index...].filter { !isOwned($0, by: sources) }
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

    private static func source(of entry: Entry) -> UInt64? {
        entry[kIOHIDKeyboardModifierMappingSrcKey] as? UInt64
    }

    private static func isOwned(_ entry: Entry, by sources: Set<UInt64>) -> Bool {
        source(of: entry).map(sources.contains) == true
    }

    mutating func sync(_ current: [UInt64: Mapping], remapping: Set<UInt64>) -> [UInt64: Mapping] {
        originals = originals.filter { current[$0.key] != nil }
        var writes: [UInt64: Mapping] = [:]
        for (id, mapping) in current {
            let entries = remapping.contains(id) ? remapped : others
            let sources = Set(entries.compactMap(Self.source))
            var target = mapping
            if let original = originals[id], original.sources != sources {
                target = Self.replacing(original.sources, in: target, with: original.entries)
                originals[id] = nil
            }
            if !entries.isEmpty {
                originals[id] =
                    originals[id]
                    ?? Original(
                        sources: sources, entries: target.filter { Self.isOwned($0, by: sources) })
                target = Self.replacing(sources, in: target, with: entries)
            }
            if target != mapping {
                writes[id] = target
            }
        }
        return writes
    }

    mutating func keepOriginals(of ids: Set<UInt64>, from earlier: Self) {
        for id in ids {
            originals[id] = earlier.originals[id] ?? originals[id]
        }
    }

    func restores(from current: [UInt64: Mapping]) -> [UInt64: Mapping] {
        originals.reduce(into: [:]) { restores, original in
            guard let mapping = current[original.key] else { return }
            restores[original.key] = Self.replacing(
                original.value.sources, in: mapping, with: original.value.entries)
        }
    }

    mutating func restore(from current: [UInt64: Mapping]) -> [UInt64: Mapping] {
        defer { originals = [:] }
        return restores(from: current)
    }
}
