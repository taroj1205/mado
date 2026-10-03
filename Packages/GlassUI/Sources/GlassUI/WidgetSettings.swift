public struct WidgetSettings: Codable, Equatable, Sendable {
    private var custom: Bool
    private var added: [String]

    public init() {
        custom = false
        added = []
    }

    public func added(from available: [String]) -> [String] {
        guard custom else { return available }
        var seen: Set<String> = []
        return added.filter { available.contains($0) && seen.insert($0).inserted }
    }

    public mutating func add(_ id: String, from available: [String]) {
        guard available.contains(id), !added(from: available).contains(id) else { return }
        added = (custom ? added : available) + [id]
        custom = true
    }
}
