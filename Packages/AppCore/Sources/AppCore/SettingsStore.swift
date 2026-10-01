public import Foundation

public struct SettingsStore: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public static func standard() throws -> Self {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        #if DEBUG
            let name = "settings.debug.json"
        #else
            let name = "settings.json"
        #endif
        return Self(url: base.appending(path: "Mado/\(name)"))
    }

    public func load() throws -> Settings {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            return Settings()
        }
        guard
            case .object(var root) = try? JSONDecoder().decode(
                JSONValue.self, from: Data(contentsOf: url))
        else {
            throw SettingsError.corrupt
        }
        var version = 0
        if case .number(let stored) = root["version"] {
            version = Int(stored)
        }
        guard version <= Settings.currentVersion else {
            throw SettingsError.unsupportedVersion(version)
        }
        if version == 0 {
            root = ["version": .number(1), "modules": .object(root)]
        }
        guard case .object(let modules) = root["modules"] else {
            throw SettingsError.corrupt
        }
        return Settings(modules: modules)
    }

    public func save(_ settings: Settings) throws {
        let root: JSONValue = .object([
            "version": .number(Double(Settings.currentVersion)),
            "modules": .object(settings.modules),
        ])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(root).write(to: url, options: .atomic)
    }
}
