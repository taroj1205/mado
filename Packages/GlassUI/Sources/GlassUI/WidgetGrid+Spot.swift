import AppKit

extension WidgetGrid {
    public enum Spot: String, CaseIterable, Codable, Sendable {
        case panel = "in_panel"
        case aboveLeft = "above_left"
        case aboveCentre = "above_centre"
        case aboveRight = "above_right"
        case leftTop = "left_top"
        case leftMiddle = "left_middle"
        case leftBottom = "left_bottom"
        case rightTop = "right_top"
        case rightMiddle = "right_middle"
        case rightBottom = "right_bottom"

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

        public var title: String {
            switch self {
            case .panel: "In the panel"
            case .aboveLeft: "Above · Left"
            case .aboveCentre: "Above · Centre"
            case .aboveRight: "Above · Right"
            case .leftTop: "Left · Top"
            case .leftMiddle: "Left · Middle"
            case .leftBottom: "Left · Bottom"
            case .rightTop: "Right · Top"
            case .rightMiddle: "Right · Middle"
            case .rightBottom: "Right · Bottom"
            }
        }

        var side: Side {
            switch self {
            case .panel: .panel
            case .aboveLeft, .aboveCentre, .aboveRight: .above
            case .leftTop, .leftMiddle, .leftBottom: .left
            case .rightTop, .rightMiddle, .rightBottom: .right
            }
        }

        var anchor: Anchor {
            switch self {
            case .panel, .aboveLeft, .leftTop, .rightTop: .start
            case .aboveCentre, .leftMiddle, .rightMiddle: .middle
            case .aboveRight, .leftBottom, .rightBottom: .end
            }
        }

        public func neighbour(toward heading: Heading) -> Self? {
            Self.neighbours[self]?[heading]
        }
    }

    public enum Heading: Sendable {
        case top
        case bottom
        case left
        case right
    }

    enum Side {
        case panel
        case above
        case left
        case right
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
            spot(of: widget) == .panel && !(tileLayout == .strip && widget.isTall)
        }
        let rows =
            tileLayout == .strip
            ? Self.cells(of: panelWidgets).count { $0.rows.lowerBound == 0 } : nil
        let around = Spot.allCases.dropFirst().flatMap { spot in
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

    var overhang: CGFloat {
        let rows = CGFloat(Self.shelfRows(of: placed))
        guard rows > 0 else { return 0 }
        return Self.lift + rows * Self.rowHeight + (rows - 1) * Self.floatingGap
    }

    func spot(of widget: Widget) -> Spot {
        if widget.id == dragged, let moving { return moving }
        return home(of: widget.id)
    }

    func home(of id: String) -> Spot {
        spots[id] ?? .panel
    }
}
