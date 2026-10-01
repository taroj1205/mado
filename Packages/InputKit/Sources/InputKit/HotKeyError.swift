public import AppCore

public enum HotKeyError: Error, Equatable {
    case duplicate(Shortcut)
    case handlerInstallFailed(Int32)
    case refused(Int32)
}
