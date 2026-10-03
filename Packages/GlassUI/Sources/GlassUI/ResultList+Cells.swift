import AppKit

extension ResultList {
    var rowRadius: CGFloat {
        compact ? Self.compactRadius : ResultRowView.radius
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
