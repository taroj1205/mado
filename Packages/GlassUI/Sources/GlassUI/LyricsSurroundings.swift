public import AppKit

public struct LyricsSurroundings: Equatable, Sendable {
    public var dock: NSRect?
    public var menusEnd: CGFloat?
    public var statusItems: [NSRect]

    public init(dock: NSRect? = nil, menusEnd: CGFloat? = nil, statusItems: [NSRect] = []) {
        self.dock = dock
        self.menusEnd = menusEnd
        self.statusItems = statusItems
    }
}
