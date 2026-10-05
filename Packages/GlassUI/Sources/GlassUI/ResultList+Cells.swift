import AppKit

extension ResultList {
    var answerRow: Int? { rows.firstIndex(where: \.isAnswer) }

    var belowAnswer: CGFloat {
        (answerRow.map { table.rect(ofRow: $0).maxY } ?? 0) + Self.topInset
    }

    var rowRadius: CGFloat {
        compact ? Self.compactRadius : ResultRowView.radius
    }

    static func rows(for sections: [Section]) -> [Row] {
        sections.filter { !$0.items.isEmpty || $0.notice != nil }
            .flatMap { section in
                let above: [Row?] = [
                    section.notice.map(Row.notice), section.card.map(Row.card),
                    section.colour.map(Row.colour),
                ]
                let items = section.items.map(Row.item)
                return above.compactMap(\.self) + (items.isEmpty ? [] : [.header(section.title)])
                    + items
            }
    }

    func radius(ofRow row: Int) -> CGFloat {
        if rows[row].isAnswer || rows[row].isWidget {
            AnswerCell.radius
        } else {
            rowRadius
        }
    }

    func reloadRows(keeping shown: Int) {
        let kept = IndexSet(integersIn: 0..<min(shown, rows.count))
        if rows.count < shown {
            table.removeRows(at: IndexSet(integersIn: rows.count..<shown), withAnimation: [])
        } else if rows.count > shown {
            table.insertRows(at: IndexSet(integersIn: shown..<rows.count), withAnimation: [])
        }
        table.reloadData(forRowIndexes: kept, columnIndexes: [0])
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            table.noteHeightOfRows(withIndexesChanged: kept)
        }
        table.enumerateAvailableRowViews { rowView, row in
            guard let view = rowView as? ResultRowView, rows.indices.contains(row) else { return }
            view.radius = radius(ofRow: row)
            view.needsDisplay = true
        }
    }

    private func check(of item: Item) -> GlyphCell.Check {
        if checked.isEmpty { .off } else if checked.contains(item.id) { .checked } else { .empty }
    }

    func height(of item: Item) -> CGFloat {
        if let widget = item.widget { return WidgetCell.height(for: widget) }
        if item.answer != nil { return Self.answerHeight }
        if item.event != nil { return Self.eventHeight }
        return compact ? Self.compactRowHeight : Self.rowHeight
    }

    func cell(for item: Item, in tableView: NSTableView) -> NSView {
        if let widget = item.widget {
            let cell =
                tableView.makeView(withIdentifier: WidgetCell.id, owner: nil)
                as? WidgetCell ?? WidgetCell()
            cell.show(widget)
            return cell
        }
        if item.answer != nil {
            let cell =
                tableView.makeView(withIdentifier: AnswerCell.id, owner: nil)
                as? AnswerCell ?? AnswerCell()
            cell.show(item)
            return cell
        }
        if let event = item.event {
            let cell =
                tableView.makeView(withIdentifier: EventCell.id, owner: nil)
                as? EventCell ?? EventCell()
            cell.show(item, event)
            return cell
        }
        if compact {
            let cell =
                tableView.makeView(withIdentifier: GlyphCell.id, owner: nil)
                as? GlyphCell ?? GlyphCell()
            cell.show(item, check: check(of: item))
            return cell
        }
        let cell =
            tableView.makeView(withIdentifier: ResultCell.id, owner: nil)
            as? ResultCell ?? ResultCell()
        cell.show(item)
        return cell
    }
}
