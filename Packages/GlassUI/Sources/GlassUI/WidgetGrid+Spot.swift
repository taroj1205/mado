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

    var shown: [Widget] {
        guard let layoutInUse else { return [] }
        let listed = editing ? widgets : widgets.filter { !$0.isUnavailable }
        let arranged =
            order.isEmpty ? listed : order.compactMap { id in listed.first { $0.id == id } }
        let panelWidgets = arranged.filter { spot(of: $0) == .panel }
        let rows =
            layoutInUse == .strip ? Self.cells(of: panelWidgets).count { $0.row == 0 } : nil
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
        layoutInUse == .grid && widgets.contains { spot(of: $0) == .panel }
    }

    var spans: [Int] { inPanel.map(\.span) + (incoming.map { [$0] } ?? []) }

    var overhang: CGFloat {
        let rows = CGFloat(Self.shelfRows(of: placed))
        guard rows > 0 else { return 0 }
        return Self.lift + rows * Self.rowHeight + (rows - 1) * Self.floatingGap
    }

    func spot(of widget: Widget) -> Spot {
        editing ? .panel : spots[widget.id] ?? .panel
    }
}
