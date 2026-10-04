import Carbon.HIToolbox

public struct InputSource: Sendable {
    @MainActor private static var cycle = InputCycle()

    @MainActor
    public static var enabled: [Self] {
        sources(matching: [:], includeAllInstalled: false).compactMap(Self.init)
    }

    @MainActor
    public static var currentID: String? {
        guard let source = unsafe TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
        else { return nil }
        return string(source, kTISPropertyInputSourceID)
    }

    @MainActor
    public static var currentTypesASCII: Bool {
        guard let source = unsafe TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
            let value = unsafe TISGetInputSourceProperty(
                source, kTISPropertyInputSourceIsASCIICapable)
        else { return false }
        return CFBooleanGetValue(
            unsafe Unmanaged<CFBoolean>.fromOpaque(value).takeUnretainedValue())
    }

    public let id: String
    public let name: String

    private init?(_ source: TISInputSource) {
        guard let sourceID = Self.string(source, kTISPropertyInputSourceID),
            let localizedName = Self.string(source, kTISPropertyLocalizedName)
        else { return nil }
        id = sourceID
        name = localizedName
    }

    @MainActor
    public static func named(_ id: String) -> String? {
        sources(matching: [kTISPropertyInputSourceID: id], includeAllInstalled: true).first
            .flatMap { string($0, kTISPropertyLocalizedName) }
    }

    @MainActor
    public static func select(_ id: String) {
        guard
            let source = sources(
                matching: [kTISPropertyInputSourceID: id], includeAllInstalled: false
            ).first
        else { return }
        select(source)
    }

    @MainActor
    public static func selectNext() {
        if let nextID = cycle.next(after: currentID, in: enabled.map(\.id), at: .now) {
            select(nextID)
        }
    }

    @MainActor
    static func select(_ source: TISInputSource) {
        guard string(source, kTISPropertyInputSourceID) != currentID else { return }
        TISSelectInputSource(source)
    }

    @MainActor
    static func sources(
        matching filter: [CFString: String], includeAllInstalled: Bool
    ) -> [TISInputSource] {
        var properties: [String: Any] = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String,
            kTISPropertyInputSourceIsSelectCapable as String: true,
        ]
        for (key, value) in filter {
            properties[key as String] = value
        }
        return unsafe TISCreateInputSourceList(properties as CFDictionary, includeAllInstalled)?
            .takeRetainedValue() as? [TISInputSource] ?? []
    }

    static func string(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let value = unsafe TISGetInputSourceProperty(source, key) else { return nil }
        return unsafe Unmanaged<CFString>.fromOpaque(value).takeUnretainedValue() as String
    }
}
