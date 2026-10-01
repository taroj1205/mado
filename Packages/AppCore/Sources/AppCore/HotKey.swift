public enum HotKey: Hashable, Sendable {
    case modifierTap(ModifierKey)
    case shortcut(Shortcut)

    public enum ModifierKey: Hashable, Sendable {
        case leftCommand
        case leftControl
        case leftOption
        case leftShift
        case rightCommand
        case rightControl
        case rightOption
        case rightShift
    }
}
