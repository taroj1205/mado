import Carbon.HIToolbox

@safe
struct SystemHotKeyPause {
    private var token: UnsafeMutableRawPointer?

    var isActive: Bool { unsafe token != nil }

    mutating func begin() {
        guard unsafe token == nil else { return }
        unsafe token = PushSymbolicHotKeyMode(
            OptionBits(kHIHotKeyModeAllDisabledExceptUniversalAccess))
    }

    mutating func end() {
        guard let current = unsafe token else { return }
        unsafe PopSymbolicHotKeyMode(current)
        unsafe self.token = nil
    }
}
