public import Foundation

public struct Snippet: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public var name: String
    public var keyword: String
    public var text: String

    public init(name: String, keyword: String, text: String, id: String = UUID().uuidString) {
        self.id = id
        self.name = name
        self.keyword = keyword
        self.text = text
    }
}
