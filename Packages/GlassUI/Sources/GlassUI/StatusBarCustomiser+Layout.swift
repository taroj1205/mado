import AppKit

extension StatusBarCustomiser {
    private static let headerHeight: CGFloat = 54
    private static let footerHeight: CGFloat = 40
    private static let side: CGFloat = 16
    private static let doneSide: CGFloat = 10
    private static let footerSide: CGFloat = 12
    private static let titleGap: CGFloat = 2
    private static let doneGap: CGFloat = 11
    private static let titleSize: CGFloat = 14
    private static let noteSize: CGFloat = 12
    private static let resetSize: CGFloat = 12.5
    private static let headingSide: CGFloat = 10
    private static let listSide: CGFloat = 6
    private static let listTop: CGFloat = 4
    private static let listBottom: CGFloat = 8

    static func heading(_ title: String) -> NSView {
        let text = label(title, font: headingFont, color: .secondaryLabelColor)
        let view = NSView()
        view.addSubview(text)
        NSLayoutConstraint.activate([
            text.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: headingSide),
            text.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -headingBottom),
        ])
        return view
    }

    private static func label(_ text: String, font: NSFont, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private static func separator() -> NSBox {
        let line = NSBox()
        line.boxType = .separator
        return line
    }

    func makeContent() -> NSView {
        let list = makeList()
        let column = NSStackView(views: [
            makeHeader(), Self.separator(), list, Self.separator(), makeFooter(),
        ])
        column.orientation = .vertical
        column.alignment = .centerX
        column.distribution = .fill
        column.spacing = 0
        for view in column.arrangedSubviews where view !== list {
            view.widthAnchor.constraint(equalTo: column.widthAnchor).isActive = true
        }
        list.widthAnchor.constraint(
            equalTo: column.widthAnchor, constant: -(Self.listSide + Self.listSide)
        ).isActive = true
        return column
    }

    private func makeHeader() -> NSView {
        let note = Self.label(
            "Shown when the search is empty · drag to reorder",
            font: .systemFont(ofSize: Self.noteSize), color: .secondaryLabelColor)
        note.lineBreakMode = .byTruncatingTail
        note.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let titles = NSStackView(views: [
            Self.label(
                "Status bar", font: .systemFont(ofSize: Self.titleSize, weight: .semibold),
                color: .labelColor),
            note,
        ])
        titles.orientation = .vertical
        titles.alignment = .leading
        titles.spacing = Self.titleGap
        let header = NSView()
        for view in [titles, done] {
            view.translatesAutoresizingMaskIntoConstraints = false
            header.addSubview(view)
        }
        NSLayoutConstraint.activate([
            header.heightAnchor.constraint(equalToConstant: Self.headerHeight),
            titles.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: Self.side),
            titles.trailingAnchor.constraint(
                lessThanOrEqualTo: done.leadingAnchor, constant: -Self.doneGap),
            titles.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            done.trailingAnchor.constraint(
                equalTo: header.trailingAnchor, constant: -Self.doneSide),
            done.centerYAnchor.constraint(equalTo: header.centerYAnchor),
        ])
        return header
    }

    private func makeList() -> NSScrollView {
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.automaticallyAdjustsContentInsets = false
        scroll.contentInsets = NSEdgeInsets(
            top: Self.listTop, left: 0, bottom: Self.listBottom, right: 0)
        scroll.setContentHuggingPriority(.defaultLow, for: .vertical)
        return scroll
    }

    private func makeFooter() -> NSView {
        count.font = .systemFont(ofSize: Self.noteSize)
        count.textColor = .secondaryLabelColor
        reset.isBordered = false
        reset.refusesFirstResponder = true
        reset.attributedTitle = NSAttributedString(
            string: reset.title,
            attributes: [
                .font: NSFont.systemFont(ofSize: Self.resetSize, weight: .semibold),
                .foregroundColor: NSColor.controlAccentColor,
            ])
        let footer = NSView()
        for view in [count, reset] {
            view.translatesAutoresizingMaskIntoConstraints = false
            footer.addSubview(view)
        }
        NSLayoutConstraint.activate([
            footer.heightAnchor.constraint(equalToConstant: Self.footerHeight),
            count.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: Self.side),
            count.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
            reset.trailingAnchor.constraint(
                equalTo: footer.trailingAnchor, constant: -Self.footerSide),
            reset.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
        ])
        return footer
    }
}
