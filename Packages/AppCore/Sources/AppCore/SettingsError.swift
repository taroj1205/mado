public enum SettingsError: Error, Equatable {
    case corrupt
    case unsupportedVersion(Int)
}
