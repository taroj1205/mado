import AppKit

extension ResultList {
    var rowRadius: CGFloat {
        compact ? Self.compactRadius : ResultRowView.radius
    }

    func radius(ofRow row: Int) -> CGFloat {
        if case .item(let item) = rows[row], item.answer != nil {
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

    func cell(for item: Item, in tableView: NSTableView) -> NSView {
        if item.answer != nil {
            let cell =
                tableView.makeView(withIdentifier: AnswerCell.id, owner: nil)
                as? AnswerCell ?? AnswerCell()
            cell.show(item)
            return cell
        }
        if compact {
            let cell =
                tableView.makeView(withIdentifier: GlyphCell.id, owner: nil)
                as? GlyphCell ?? GlyphCell()
            cell.show(item)
            return cell
        }
        let cell =
            tableView.makeView(withIdentifier: ResultCell.id, owner: nil)
            as? ResultCell ?? ResultCell()
        cell.show(item)
        return cell
    }
}
