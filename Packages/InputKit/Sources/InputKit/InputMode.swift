import Carbon.HIToolbox

public enum InputMode: Sendable {
    case english
    case japanese

    private static let japaneseModeID = "com.apple.inputmethod.Japanese"

    @MainActor
    public func select() {
        let current = unsafe TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
        guard let target = source(current: current),
            InputSource.property(target, kTISPropertyInputSourceID)
                != current.flatMap({ InputSource.property($0, kTISPropertyInputSourceID) })
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
            let bundle = current.flatMap { InputSource.property($0, kTISPropertyBundleID) }
            return sources.first { InputSource.property($0, kTISPropertyBundleID) == bundle }
                ?? sources.first
        }
    }
}
