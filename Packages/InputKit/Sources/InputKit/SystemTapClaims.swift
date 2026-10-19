import CoreFoundation

public enum SystemTapClaims {
    private enum FnUsage: Int {
        case changeInputSource = 1
        case dictation = 3
        case emojiPicker = 2
    }

    private static let domain = "com.apple.HIToolbox"
    private static let fnUsageKey = "AppleFnUsageType"
    private static let doubleTap = 2

    public static func use(of tap: ModifierTap.Tap) -> String? {
        let stored = CFPreferencesCopyAppValue(fnUsageKey as CFString, domain as CFString)
        return use(of: tap, fnUsage: stored as? Int)
    }

    static func use(of tap: ModifierTap.Tap, fnUsage: Int?) -> String? {
        guard tap.keys == [.function] else { return nil }
        let stored = fnUsage ?? FnUsage.emojiPicker.rawValue
        switch (tap.count, FnUsage(rawValue: stored)) {
        case (1, .changeInputSource): return "switching input sources"
        case (1, .emojiPicker): return "the emoji picker"
        case (doubleTap, .dictation): return "dictation"
        default: return nil
        }
    }
}
