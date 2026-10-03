import Carbon.HIToolbox

public enum InputMode: Sendable {
    case english
    case japanese

    private static let japaneseModeID = "com.apple.inputmethod.Japanese"

    @MainActor
    public func select() {
        guard let target = source() else { return }
        InputSource.select(target)
    }

    @MainActor
    private func source() -> TISInputSource? {
        switch self {
        case .english:
            return unsafe TISCopyCurrentASCIICapableKeyboardInputSource()?.takeRetainedValue()

        case .japanese:
            let sources = InputSource.sources(
                matching: [kTISPropertyInputModeID: Self.japaneseModeID],
                includeAllInstalled: false)
            let current = unsafe TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
            let bundle = current.flatMap { InputSource.string($0, kTISPropertyBundleID) }
            return sources.first { InputSource.string($0, kTISPropertyBundleID) == bundle }
                ?? sources.first
        }
    }
}
