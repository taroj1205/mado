import Carbon.HIToolbox

public struct InputSource: Equatable, Sendable {
    @MainActor public static var current: Self? {
        unsafe TISCopyCurrentKeyboardInputSource().flatMap { Self(unsafe $0.takeRetainedValue()) }
    }

    @MainActor public static var selectable: [Self] {
        sources(
            [
                kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource
                    as String,
                kTISPropertyInputSourceIsSelectCapable as String: true,
            ],
            includingDisabled: false
        )
        .compactMap(Self.init)
    }

    public let id: String
    public let name: String

    private init?(_ source: TISInputSource) {
        guard let sourceID = Self.property(source, kTISPropertyInputSourceID) else { return nil }
        id = sourceID
        name = Self.property(source, kTISPropertyLocalizedName) ?? sourceID
    }

    @MainActor
    public static func installed(id: String) -> Self? {
        sources([kTISPropertyInputSourceID as String: id], includingDisabled: true)
            .lazy.compactMap(Self.init).first
    }

    @MainActor
    public static func select(id: String) -> Bool {
        if current?.id == id {
            return true
        }
        guard
            let source = sources(
                [kTISPropertyInputSourceID as String: id], includingDisabled: false
            ).first
        else {
            return false
        }
        return TISSelectInputSource(source) == noErr
    }

    static func property(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let value = unsafe TISGetInputSourceProperty(source, key) else { return nil }
        return unsafe Unmanaged<CFString>.fromOpaque(value).takeUnretainedValue() as String
    }

    private static func sources(
        _ filter: [String: Any], includingDisabled: Bool
    ) -> [TISInputSource] {
        unsafe TISCreateInputSourceList(filter as CFDictionary, includingDisabled)?
            .takeRetainedValue() as? [TISInputSource] ?? []
    }
}
