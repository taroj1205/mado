import Carbon.HIToolbox

public enum InputMode: Sendable {
    case english
    case japanese

    private static let japaneseModeID = "com.apple.inputmethod.Japanese"

    private static func property(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let value = unsafe TISGetInputSourceProperty(source, key) else { return nil }
        return unsafe Unmanaged<CFString>.fromOpaque(value).takeUnretainedValue() as String
    }

    @MainActor
    public func select() {
        let current = unsafe TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
        guard let target = source(current: current),
            Self.property(target, kTISPropertyInputSourceID)
                != current.flatMap({ Self.property($0, kTISPropertyInputSourceID) })
        else {
            return
        }
        TISSelectInputSource(target)
    }

    private func source(current: TISInputSource?) -> TISInputSource? {
        switch self {
        case .english:
            return unsafe TISCopyCurrentASCIICapableKeyboardInputSource()?.takeRetainedValue()

        case .japanese:
            let filter: [String: Any] = [
                kTISPropertyInputSourceIsSelectCapable as String: true,
                kTISPropertyInputModeID as String: Self.japaneseModeID,
            ]
            let sources =
                unsafe TISCreateInputSourceList(filter as CFDictionary, false)?
                .takeRetainedValue() as? [TISInputSource] ?? []
            let bundle = current.flatMap { Self.property($0, kTISPropertyBundleID) }
            return sources.first { Self.property($0, kTISPropertyBundleID) == bundle }
                ?? sources.first
        }
    }
}
