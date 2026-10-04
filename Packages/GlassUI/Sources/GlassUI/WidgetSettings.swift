public struct WidgetSettings: Codable, Equatable, Sendable {
    public enum Edit: Equatable, Sendable {
        case add(String)
        case move(String, before: String?)
        case remove(String)
    }

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

    public mutating func apply(_ edit: Edit, from available: [String]) {
        switch edit {
        case .add(let id):
            guard available.contains(id), !added(from: available).contains(id) else { return }
            added = (custom ? added : available) + [id]
            custom = true

        case let .move(id, target):
            guard id != target, added(from: available).contains(id) else { return }
            var order = (custom ? added : available).filter { $0 != id }
            order.insert(id, at: target.flatMap(order.firstIndex(of:)) ?? order.endIndex)
            added = order
            custom = true

        case .remove(let id):
            guard added(from: available).contains(id) else { return }
            added = (custom ? added : available).filter { $0 != id }
            custom = true
        }
    }
}
