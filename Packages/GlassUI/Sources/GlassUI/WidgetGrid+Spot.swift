import AppKit

extension WidgetGrid {
    public struct Spot: Hashable, Comparable, Sendable, Codable {
        static let rowsAbove = 3
        static let stops = 5
        private static let centreColumn = 2
        private static let middleStop = 2
        private static let coordinates = 2
        private static let middleStart = 2
        private static let aboveEnd = 4
        private static let alongEnd = 3

        public static let panel = Self(.panel, column: 0, row: 0)
        public static let aboveLeft = above(column: 0, row: 0)
        public static let aboveCentre = above(column: centreColumn, row: 0)
        public static let aboveRight = above(column: WidgetGrid.columns - 1, row: 0)
        public static let leftTop = beside(.left, row: 0)
        public static let leftMiddle = beside(.left, row: middleStop)
        public static let leftBottom = beside(.left, row: stops - 1)
        public static let rightTop = beside(.right, row: 0)
        public static let rightMiddle = beside(.right, row: middleStop)
        public static let rightBottom = beside(.right, row: stops - 1)

        static let presets: [Self] = [
            .panel, .aboveLeft, .aboveCentre, .aboveRight, .leftTop, .leftMiddle, .leftBottom,
            .rightTop, .rightMiddle, .rightBottom,
        ]

        private static let names: [Self: String] = [
            .panel: "in_panel", .aboveLeft: "above_left", .aboveCentre: "above_centre",
            .aboveRight: "above_right", .leftTop: "left_top", .leftMiddle: "left_middle",
            .leftBottom: "left_bottom", .rightTop: "right_top", .rightMiddle: "right_middle",
            .rightBottom: "right_bottom",
        ]

        private static let neighbours: [Self: [Heading: Self]] = [
            .panel: [.top: .aboveCentre, .left: .leftMiddle, .right: .rightMiddle],
            .aboveLeft: [.left: .leftTop, .right: .aboveCentre, .bottom: .panel],
            .aboveCentre: [.left: .aboveLeft, .right: .aboveRight, .bottom: .panel],
            .aboveRight: [.left: .aboveCentre, .right: .rightTop, .bottom: .panel],
            .leftTop: [.top: .aboveLeft, .bottom: .leftMiddle, .right: .panel],
            .leftMiddle: [.top: .leftTop, .bottom: .leftBottom, .right: .panel],
            .leftBottom: [.top: .leftMiddle, .right: .panel],
            .rightTop: [.top: .aboveRight, .bottom: .rightMiddle, .left: .panel],
            .rightMiddle: [.top: .rightTop, .bottom: .rightBottom, .left: .panel],
            .rightBottom: [.top: .rightMiddle, .left: .panel],
        ]

        private static let stopNames = ["Top", "Upper", "Middle", "Lower", "Bottom"]
        private static let columnNames = [
            0: "Left", centreColumn: "Centre", WidgetGrid.columns - 1: "Right",
        ]

        let side: Side
        let column: Int
        let row: Int

        var name: String {
            Self.names[self] ?? [side.rawValue, "\(column)", "\(row)"].joined(separator: ":")
        }

        public var title: String {
            switch side {
            case .panel:
                return "In the panel"

            case .above:
                let place = Self.columnNames[column] ?? "Column \(column + 1)"
                return row > 0 ? "Above · \(place), Row \(row + 1)" : "Above · \(place)"

            case .left, .right:
                return "\(side == .left ? "Left" : "Right") · \(Self.stopNames[row])"
            }
        }

        var anchor: Anchor {
            let (place, ends) =
                side == .above ? (column, Self.aboveEnd) : (row, Self.alongEnd)
            if side == .panel || place < Self.middleStart { return .start }
            return place < ends ? .middle : .end
        }

        private var reading: [Int] {
            [Side.allCases.firstIndex(of: side) ?? 0, side == .above ? -row : row, column]
        }

        var preset: Self {
            Self.presets.first { $0.side == side && $0.anchor == anchor } ?? .panel
        }

        private init(_ side: Side, column: Int, row: Int) {
            self.side = side
            let width = side == .above ? WidgetGrid.columns : 1
            let height =
                switch side {
                case .panel: 1
                case .above: Self.rowsAbove
                case .left, .right: Self.stops
                }
            self.column = min(max(column, 0), width - 1)
            self.row = min(max(row, 0), height - 1)
        }

        init?(name text: String) {
            if let named = Self.names.first(where: { $0.value == text })?.key {
                self = named
                return
            }
            let parts = text.split(separator: ":").map(String.init)
            let numbers = parts.dropFirst().compactMap { Int($0) }
            guard let kind = parts.first.flatMap(Side.init(rawValue:)), kind != .panel,
                parts.count == Self.coordinates + 1, numbers.count == Self.coordinates,
                let across = numbers.first, let down = numbers.last
            else { return nil }
            self.init(kind, column: across, row: down)
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let spot = Self(name: text) else {
                throw DecodingError.dataCorruptedError(
                    in: container, debugDescription: "Unknown widget spot \(text)")
            }
            self = spot
        }

        static func above(column: Int, row: Int) -> Self {
            Self(.above, column: column, row: row)
        }

        static func beside(_ side: Side, row: Int) -> Self {
            Self(side, column: 0, row: row)
        }

        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.reading.lexicographicallyPrecedes(rhs.reading)
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(name)
        }

        public func neighbour(toward heading: Heading) -> Self? {
            Self.neighbours[preset]?[heading]
        }

        func step(toward heading: Heading) -> Self? {
            switch side {
            case .panel: Self.neighbours[self]?[heading]
            case .above: stepAbove(heading)
            case .left, .right: stepAlong(heading)
            }
        }

        private func stepAbove(_ heading: Heading) -> Self? {
            switch heading {
            case .left: column > 0 ? .above(column: column - 1, row: row) : .leftTop

            case .right:
                column < WidgetGrid.columns - 1 ? .above(column: column + 1, row: row) : .rightTop

            case .top: row < Self.rowsAbove - 1 ? .above(column: column, row: row + 1) : nil
            case .bottom: row > 0 ? .above(column: column, row: row - 1) : .panel
            }
        }

        private func stepAlong(_ heading: Heading) -> Self? {
            switch heading {
            case .top: row > 0 ? .beside(side, row: row - 1) : Self.neighbours[self]?[.top]

            case .bottom: row < Self.stops - 1 ? .beside(side, row: row + 1) : nil
            case .left: side == .right ? .panel : nil
            case .right: side == .left ? .panel : nil
            }
        }
    }

    public enum Heading: Sendable {
        case top
        case bottom
        case left
        case right
    }

    enum Side: String, CaseIterable {
        case panel = "in_panel"
        case above = "above"
        case left = "left"
        case right = "right"

        static let rails: [Self] = [.left, .right]
    }

    enum Anchor {
        case start
        case middle
        case end
    }

    var listed: [Widget] {
        let own = editing ? widgets : widgets.filter { !$0.isUnavailable }
        guard let incoming, moving != nil else { return own }
        return own + [incoming]
    }

    var shown: [Widget] {
        guard let tileLayout else { return [] }
        let available = listed
        let arranged =
            order.isEmpty ? available : order.compactMap { id in available.first { $0.id == id } }
        let panelWidgets = arranged.filter { spot(of: $0) == .panel }
        let rows =
            tileLayout == .strip ? Self.cells(of: panelWidgets).count { $0.row == 0 } : nil
        let around = Set(arranged.map(spot)).subtracting([.panel]).sorted().flatMap { spot in
            arranged.filter { self.spot(of: $0) == spot }
        }
        return Array(panelWidgets.prefix(rows ?? panelWidgets.count)) + around
    }

    var inPanel: [Widget] { shown.filter { spot(of: $0) == .panel } }

    var placed: [Placed] {
        shown.compactMap { widget in
            let spot = spot(of: widget)
            return spot == .panel ? nil : (widget, spot)
        }
    }

    var fillsPanel: Bool {
        tileLayout == .grid && widgets.contains { spot(of: $0) == .panel }
    }

    var spans: [Int] { inPanel.map(\.span) }

    var overhang: CGFloat {
        let rows = CGFloat(Self.shelfRows(of: placed))
        guard rows > 0 else { return 0 }
        return Self.lift + rows * Self.rowHeight + (rows - 1) * Self.floatingGap
    }

    func spot(of widget: Widget) -> Spot {
        if let moving, let dragged, unit(of: dragged).contains(widget.id) { return moving }
        return home(of: widget.id)
    }

    func home(of id: String) -> Spot {
        spots[id] ?? .panel
    }

    func members(_ ids: [String]) -> [Widget] {
        ids.compactMap { id in
            widgets.first { $0.id == id } ?? incoming.flatMap { $0.id == id ? $0 : nil }
        }
    }

    func unit(of id: String) -> [String] {
        let home = home(of: id)
        guard home != .panel, incoming?.id != id else { return [id] }
        return widgets.map(\.id).filter { self.home(of: $0) == home }
    }
}
