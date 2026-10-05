import AppKit

extension WidgetGrid {
    public struct Spot: Hashable, Comparable, Sendable, Codable {
        static let shelfRows = 3
        static let panelRows = 2
        static let stops = 6
        private static let centreColumn = 2
        private static let middleStop = 2
        private static let coordinates = 2
        private static let middleStart = 2
        private static let aboveEnd = 4
        private static let alongEnd = 4

        public static let panel = Self()
        public static let aboveLeft = above(column: 0, row: 0)
        public static let aboveCentre = above(column: centreColumn, row: 0)
        public static let aboveRight = above(column: WidgetGrid.columns - 1, row: 0)
        public static let belowLeft = below(column: 0, row: 0)
        public static let belowCentre = below(column: centreColumn, row: 0)
        public static let belowRight = below(column: WidgetGrid.columns - 1, row: 0)
        public static let leftTop = beside(.left, row: 0)
        public static let leftMiddle = beside(.left, row: middleStop)
        public static let leftBottom = beside(.left, row: stops - 1)
        public static let rightTop = beside(.right, row: 0)
        public static let rightMiddle = beside(.right, row: middleStop)
        public static let rightBottom = beside(.right, row: stops - 1)

        static let presets: [Self] = [
            .panel, .aboveLeft, .aboveCentre, .aboveRight, .belowLeft, .belowCentre, .belowRight,
            .leftTop, .leftMiddle, .leftBottom, .rightTop, .rightMiddle, .rightBottom,
        ]

        private static let names: [Self: String] = [
            .panel: "in_panel", .aboveLeft: "above_left", .aboveCentre: "above_centre",
            .aboveRight: "above_right", .belowLeft: "below_left", .belowCentre: "below_centre",
            .belowRight: "below_right", .leftTop: "left_top", .leftMiddle: "left_middle",
            .leftBottom: "left_bottom", .rightTop: "right_top", .rightMiddle: "right_middle",
            .rightBottom: "right_bottom",
        ]

        private static let neighbours: [Self: [Heading: Self]] = [
            .panel: [
                .top: .aboveCentre, .bottom: .belowCentre, .left: .leftMiddle,
                .right: .rightMiddle,
            ],
            .aboveLeft: [.left: .leftTop, .right: .aboveCentre, .bottom: .panel],
            .aboveCentre: [.left: .aboveLeft, .right: .aboveRight, .bottom: .panel],
            .aboveRight: [.left: .aboveCentre, .right: .rightTop, .bottom: .panel],
            .leftTop: [.top: .aboveLeft, .bottom: .leftMiddle, .right: .panel],
            .leftMiddle: [.top: .leftTop, .bottom: .leftBottom, .right: .panel],
            .leftBottom: [.top: .leftMiddle, .right: .panel, .bottom: .belowLeft],
            .belowLeft: [.left: .leftBottom, .right: .belowCentre, .top: .panel],
            .belowCentre: [.left: .belowLeft, .right: .belowRight, .top: .panel],
            .belowRight: [.left: .belowCentre, .right: .rightBottom, .top: .panel],
            .rightTop: [.top: .aboveRight, .bottom: .rightMiddle, .left: .panel],
            .rightMiddle: [.top: .rightTop, .bottom: .rightBottom, .left: .panel],
            .rightBottom: [.top: .rightMiddle, .left: .panel, .bottom: .belowRight],
        ]

        private static let stopNames = ["Top", "Upper", "Middle", "Lower", "Low", "Bottom"]
        private static let columnNames = [
            0: "Left", centreColumn: "Centre", WidgetGrid.columns - 1: "Right",
        ]

        private static let flowing = -1

        let side: Side
        let column: Int
        let row: Int

        var isPinned: Bool {
            side == .panel && column != Self.flowing
        }

        var name: String {
            Self.names[self] ?? [side.rawValue, "\(column)", "\(row)"].joined(separator: ":")
        }

        public var title: String {
            switch side {
            case .panel:
                return "In the panel"

            case .above, .below:
                let place = Self.columnNames[column] ?? "Column \(column + 1)"
                let shelf = side == .above ? "Above" : "Below"
                return row > 0 ? "\(shelf) · \(place), Row \(row + 1)" : "\(shelf) · \(place)"

            case .left, .right:
                return "\(side == .left ? "Left" : "Right") · \(Self.stopNames[row])"
            }
        }

        var anchor: Anchor {
            let (place, ends) =
                side.isShelf ? (column, Self.aboveEnd) : (row, Self.alongEnd)
            if side == .panel || place < Self.middleStart { return .start }
            return place < ends ? .middle : .end
        }

        private var reading: [Int] {
            [Side.allCases.firstIndex(of: side) ?? 0, side == .above ? -row : row, column]
        }

        var preset: Self {
            Self.presets.first { $0.side == side && $0.anchor == anchor } ?? .panel
        }

        private init() {
            side = .panel
            column = Self.flowing
            row = Self.flowing
        }

        private init(_ side: Side, column: Int, row: Int) {
            self.side = side
            let width = side.isRail ? 1 : WidgetGrid.columns
            let height =
                switch side {
                case .panel: Self.panelRows
                case .above, .below: Self.shelfRows
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
            guard let kind = parts.first.flatMap(Side.init(rawValue:)),
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

        static func below(column: Int, row: Int) -> Self {
            Self(.below, column: column, row: row)
        }

        static func cell(column: Int, row: Int) -> Self {
            Self(.panel, column: column, row: row)
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

        func pin(in layout: Layout?) -> (column: Int, row: Int)? {
            isPinned ? (column, layout == .strip ? 0 : row) : nil
        }

        public func neighbour(toward heading: Heading) -> Self? {
            Self.neighbours[preset]?[heading]
        }

        func step(toward heading: Heading) -> Self? {
            switch side {
            case .panel: Self.neighbours[preset]?[heading]
            case .above: stepAbove(heading)
            case .below: stepBelow(heading)
            case .left, .right: stepAlong(heading)
            }
        }

        private func stepAbove(_ heading: Heading) -> Self? {
            switch heading {
            case .left: column > 0 ? .above(column: column - 1, row: row) : .leftTop

            case .right:
                column < WidgetGrid.columns - 1 ? .above(column: column + 1, row: row) : .rightTop

            case .top: row < Self.shelfRows - 1 ? .above(column: column, row: row + 1) : nil
            case .bottom: row > 0 ? .above(column: column, row: row - 1) : .panel
            }
        }

        private func stepBelow(_ heading: Heading) -> Self? {
            switch heading {
            case .left: column > 0 ? .below(column: column - 1, row: row) : .leftBottom

            case .right:
                column < WidgetGrid.columns - 1
                    ? .below(column: column + 1, row: row) : .rightBottom

            case .bottom: row < Self.shelfRows - 1 ? .below(column: column, row: row + 1) : nil
            case .top: row > 0 ? .below(column: column, row: row - 1) : .panel
            }
        }

        private func stepAlong(_ heading: Heading) -> Self? {
            switch heading {
            case .top: row > 0 ? .beside(side, row: row - 1) : Self.neighbours[preset]?[.top]

            case .bottom:
                row < Self.stops - 1 ? .beside(side, row: row + 1) : Self.neighbours[self]?[.bottom]

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
        case below = "below"
        case left = "left"
        case right = "right"

        static let rails: [Self] = [.left, .right]
        static let shelves: [Self] = [.above, .below]

        var isRail: Bool { Self.rails.contains(self) }
        var isShelf: Bool { Self.shelves.contains(self) }
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
        let panelWidgets = arranged.filter { widget in
            spot(of: widget).side == .panel && !(tileLayout == .strip && widget.isTall)
        }
        let rows =
            tileLayout == .strip
            ? Self.cells(of: panelWidgets, in: .strip).count { $0.row == 0 } : nil
        let around = Set(arranged.map(spot)).filter { $0.side != .panel }.sorted().flatMap { spot in
            arranged.filter { self.spot(of: $0) == spot }
        }
        return Array(panelWidgets.prefix(rows ?? panelWidgets.count)) + around
    }

    var inPanel: [Widget] { shown.filter { spot(of: $0).side == .panel } }

    var placed: [Placed] {
        shown.compactMap { widget in
            let spot = spot(of: widget)
            return spot.side == .panel ? nil : (widget, spot)
        }
    }

    var fillsPanel: Bool {
        tileLayout == .grid && widgets.contains { spot(of: $0).side == .panel }
    }

    var panelCells: [Cell] {
        Self.cells(spanning: panelPlacements(of: inPanel))
    }

    var overhang: CGFloat {
        reach(of: .above)
    }

    var underhang: CGFloat {
        reach(of: .below)
    }

    private func reach(of side: Side) -> CGFloat {
        let rows = Self.shelfRows(of: placed, on: side)
        guard rows > 0 else { return 0 }
        return Self.lift + Self.extent(of: rows, unit: Self.rowHeight, gap: Self.gap)
    }

    func panelPlacements(of widgets: [Widget]) -> [Placement] {
        widgets.map { widget in
            Placement(size: widget.size(in: tileLayout), pin: spot(of: widget).pin(in: tileLayout))
        }
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
        guard home.side != .panel, incoming?.id != id else { return [id] }
        return widgets.map(\.id).filter { self.home(of: $0) == home }
    }
}
