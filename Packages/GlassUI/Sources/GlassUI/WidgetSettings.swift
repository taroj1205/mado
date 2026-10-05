public struct WidgetSettings: Codable, Equatable, Sendable {
    public enum Arrangement: Sendable {
        case inPanel
        case above
        case around
        case custom
    }

    public enum Edit: Equatable, Sendable {
        case add(String)
        case move(String, before: String?)
        case place(String, WidgetGrid.Spot, before: String?)
        case remove(String)

        var id: String {
            switch self {
            case .add(let id), .move(let id, _), .place(let id, _, _), .remove(let id): id
            }
        }
    }

    private var custom: Bool
    private var added: [String]
    private var spots: [String: WidgetGrid.Spot]

    public init() {
        custom = false
        added = []
        spots = [:]
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        custom = try values.decode(Bool.self, forKey: .custom)
        added = try values.decode([String].self, forKey: .added)
        spots = try values.decodeIfPresent([String: WidgetGrid.Spot].self, forKey: .spots) ?? [:]
    }

    public func added(from available: [String]) -> [String] {
        guard custom else { return available }
        var seen: Set<String> = []
        return added.filter { available.contains($0) && seen.insert($0).inserted }
    }

    public func spots(
        _ arrangement: Arrangement, from available: [String]
    ) -> [String: WidgetGrid.Spot] {
        let ids = added(from: available)
        let left = (ids.count + WidgetGrid.sides - 1) / WidgetGrid.sides
        return Dictionary(
            uniqueKeysWithValues: ids.enumerated().map { index, id in
                switch arrangement {
                case .inPanel: (id, .panel)
                case .above: (id, .aboveLeft)
                case .around: (id, index < left ? .leftTop : .rightTop)
                case .custom: (id, spots[id] ?? .panel)
                }
            })
    }

    public mutating func keep(_ spots: [String: WidgetGrid.Spot]) {
        self.spots.merge(spots) { _, kept in kept }
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

        case let .place(id, spot, target):
            guard available.contains(id) else { return }
            apply(.add(id), from: available)
            spots[id] = spot
            apply(.move(id, before: target), from: available)

        case .remove(let id):
            guard added(from: available).contains(id) else { return }
            added = (custom ? added : available).filter { $0 != id }
            spots[id] = nil
            custom = true
        }
    }
}
