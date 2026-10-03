public struct AppInputSources: Codable, Equatable, Sendable {
    public enum Choice: Codable, Equatable, Sendable {
        case lastUsed
        case source(id: String)
    }

    public struct Memory: Sendable {
        private var frontmost: String?
        private var lastUsed: [String: String]

        public init(frontmost: String?) {
            self.frontmost = frontmost
            lastUsed = [:]
        }

        public mutating func activate(
            _ app: String?, leaving source: String?, with settings: AppInputSources
        ) -> String? {
            if let frontmost, let source, settings.apps[frontmost] == .lastUsed {
                lastUsed[frontmost] = source
            }
            frontmost = app
            guard let app else { return nil }
            switch settings.apps[app] {
            case .source(let id): return id
            case .lastUsed: return lastUsed[app]
            case nil: return nil
            }
        }
    }

    public var apps: [String: Choice]

    public init() {
        apps = [:]
    }
}
