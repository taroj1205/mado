public import CoreGraphics
public import Foundation

public struct Note: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var text: String
    public var frame: CGRect
    public var isOpen: Bool
    public var modified: Date

    public init(
        frame: CGRect, id: UUID = UUID(), text: String = "", isOpen: Bool = true,
        modified: Date = .now
    ) {
        self.id = id
        self.text = text
        self.frame = frame
        self.isOpen = isOpen
        self.modified = modified
    }
}
