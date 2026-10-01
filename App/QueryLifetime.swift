enum QueryLifetime: String, LauncherSetting {
    case always = "always"
    case ninetySeconds = "90"
    case off = "0"
    case thirtySeconds = "30"
    case threeMinutes = "180"

    static let allCases: [Self] = [.off, .thirtySeconds, .ninetySeconds, .threeMinutes, .always]
    static let field = "query_lifetime"
    static let fallback = Self.ninetySeconds

    var title: String {
        switch self {
        case .off: "Don't Keep"
        case .thirtySeconds: "30 Seconds"
        case .ninetySeconds: "90 Seconds"
        case .threeMinutes: "3 Minutes"
        case .always: "Always"
        }
    }

    var duration: Duration? {
        Int(rawValue).map { .seconds($0) }
    }
}
