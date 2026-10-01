import Foundation

public struct Settings: Equatable, Sendable {
    public static let currentVersion = 1

    public var modules: [String: JSONValue]

    public init(modules: [String: JSONValue] = [:]) {
        self.modules = modules
    }

    public func value<Value: Decodable>(_ type: Value.Type, for module: String) throws -> Value? {
        guard let json = modules[module] else { return nil }
        return try JSONDecoder().decode(type, from: JSONEncoder().encode(json))
    }

    public mutating func setValue<Value: Encodable>(_ value: Value, for module: String) throws {
        modules[module] = try JSONDecoder().decode(
            JSONValue.self, from: JSONEncoder().encode(value))
    }
}
