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
        case group([String], WidgetGrid.Spot, before: String?)
        case spread([String: WidgetGrid.Spot])
        case resize(String, WidgetGrid.Size)
        case remove(String)

        var id: String {
            ids.first ?? ""
        }

        var ids: [String] {
            switch self {
            case .add(let id), .move(let id, _), .place(let id, _, _), .resize(let id, _),
                .remove(let id):
                [id]

            case let .group(members, _, _): members
            case .spread(let spots): spots.keys.sorted()
            }
        }

        static func moving(
            _ ids: [String], to spot: WidgetGrid.Spot, before target: String?
        ) -> Self {
            if ids.count == 1, let single = ids.first {
                .place(single, spot, before: target)
            } else {
                .group(ids, spot, before: target)
            }
        }
    }

    private var custom: Bool
    private var added: [String]
    private var spots: [String: WidgetGrid.Spot]
    private var sizes: [String: WidgetGrid.Size]

    public init() {
        custom = false
        added = []
        spots = [:]
        sizes = [:]
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        custom = try values.decode(Bool.self, forKey: .custom)
        added = try values.decode([String].self, forKey: .added)
        spots = try values.decodeIfPresent([String: WidgetGrid.Spot].self, forKey: .spots) ?? [:]
        sizes = try values.decodeIfPresent([String: WidgetGrid.Size].self, forKey: .sizes) ?? [:]
    }

    public func added(from available: [String]) -> [String] {
        guard custom else { return available }
        var seen: Set<String> = []
        return added.filter { available.contains($0) && seen.insert($0).inserted }
    }

    public func spots(
        _ arrangement: Arrangement, from available: [String], wide: Set<String> = [],
        tall: Set<String> = []
    ) -> [String: WidgetGrid.Spot] {
        let ids = added(from: available)
        let left = (ids.count + WidgetGrid.sides - 1) / WidgetGrid.sides
        let footprints = ids.map { id in
            WidgetGrid.Size(
                columns: wide.contains(id) ? WidgetGrid.Widget.wideSpan : 1,
                rows: tall.contains(id) ? WidgetGrid.Widget.tallRows : 1)
        }
        let cells = WidgetGrid.cells(spanning: footprints)
        let rows = max(WidgetGrid.rowCount(of: cells), 1)
        let stops = footprints.indices.map { index in
            footprints[(index < left ? 0 : left)..<index].map(\.rows).reduce(0, +)
        }
        return Dictionary(
            uniqueKeysWithValues: zip(ids, cells).enumerated().map { index, item in
                let (id, cell) = item
                return switch arrangement {
                case .inPanel: (id, .panel)

                case .above:
                    (id, .above(column: cell.columns.lowerBound, row: rows - cell.rows.upperBound))

                case .around:
                    (
                        id,
                        .beside(index < left ? .left : .right, row: stops[index])
                    )

                case .custom: (id, spots[id] ?? .panel)
                }
            })
    }

    public func sizes(from available: [String]) -> [String: WidgetGrid.Size] {
        let ids = added(from: available)
        return sizes.filter { ids.contains($0.key) }
    }

    public mutating func keep(_ spots: [String: WidgetGrid.Spot]) {
        self.spots.merge(spots) { _, kept in kept }
    }

    public mutating func apply(_ edit: Edit, from available: [String]) {
        switch edit {
        case .add(let id):
            add(id, from: available)

        case let .move(id, target):
            move(id, before: target, from: available)

        case let .place(id, spot, target):
            guard available.contains(id) else { return }
            apply(.add(id), from: available)
            spots[id] = spot
            apply(.move(id, before: target), from: available)

        case let .group(ids, spot, target):
            gather(ids.filter(available.contains), at: spot, before: target, from: available)

        case .spread(let moved):
            let ids = added(from: available)
            spots.merge(moved.filter { ids.contains($0.key) }) { _, spot in spot }

        case let .resize(id, size):
            resize(id, to: size, from: available)

        case .remove(let id):
            remove(id, from: available)
        }
    }

    private mutating func add(_ id: String, from available: [String]) {
        guard available.contains(id), !added(from: available).contains(id) else { return }
        added = (custom ? added : available) + [id]
        custom = true
    }

    private mutating func move(_ id: String, before target: String?, from available: [String]) {
        guard id != target, added(from: available).contains(id) else { return }
        var order = (custom ? added : available).filter { $0 != id }
        order.insert(id, at: target.flatMap(order.firstIndex(of:)) ?? order.endIndex)
        added = order
        custom = true
    }

    private mutating func resize(_ id: String, to size: WidgetGrid.Size, from available: [String]) {
        guard added(from: available).contains(id) else { return }
        sizes[id] = size
    }

    private mutating func remove(_ id: String, from available: [String]) {
        guard added(from: available).contains(id) else { return }
        added = (custom ? added : available).filter { $0 != id }
        spots[id] = nil
        sizes[id] = nil
        custom = true
    }

    private mutating func gather(
        _ ids: [String], at spot: WidgetGrid.Spot, before target: String?, from available: [String]
    ) {
        guard !ids.isEmpty else { return }
        for id in ids {
            apply(.add(id), from: available)
            spots[id] = spot
        }
        var order = (custom ? added : available).filter { !ids.contains($0) }
        order.insert(contentsOf: ids, at: target.flatMap(order.firstIndex(of:)) ?? order.endIndex)
        added = order
        custom = true
    }
}
