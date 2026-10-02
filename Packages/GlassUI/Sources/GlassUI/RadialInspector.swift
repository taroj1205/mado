import AppKit

final class RadialInspector: NSBox {
    private final class Stack: NSStackView {
        override var isFlipped: Bool { true }
    }

    private static let height: CGFloat = 318
    private static let radius: CGFloat = 16
    private static let titleSize: CGFloat = 13
    private static let subtitleSize: CGFloat = 11.5
    private static let groupSize: CGFloat = 11
    private static let noteSize: CGFloat = 12.5
    private static let inset: CGFloat = 14
    private static let headerTop: CGFloat = 12
    private static let headerBottom: CGFloat = 10
    private static let listTop: CGFloat = 4
    private static let listSide: CGFloat = 6
    private static let listBottom: CGFloat = 8
    private static let groupTop: CGFloat = 10
    private static let groupSide: CGFloat = 8
    private static let groupBottom: CGFloat = 4
    private static let headerGap: CGFloat = 2
    private static let noteGap: CGFloat = 10
    private static let fillAlpha = (dark: 0.05, light: 0.03)
    private static let edgeAlpha = (dark: 0.06, light: 0.08)
    private static let headerInsets = NSEdgeInsets(
        top: headerTop, left: inset, bottom: headerBottom, right: inset)
    private static let listInsets = NSEdgeInsets(
        top: listTop, left: listSide, bottom: listBottom, right: listSide)
    private static let groupInsets = NSEdgeInsets(
        top: groupTop, left: groupSide, bottom: groupBottom, right: groupSide)
    private static let noteInsets = NSEdgeInsets(
        top: inset, left: inset, bottom: inset, right: inset)
    private static let fill = SheetForm.adaptive(
        dark: .white.withAlphaComponent(fillAlpha.dark),
        light: .black.withAlphaComponent(fillAlpha.light))
    private static let edge = SheetForm.adaptive(
        dark: .white.withAlphaComponent(edgeAlpha.dark),
        light: .black.withAlphaComponent(edgeAlpha.light))
    private static let notes = [
        "The hole always cancels, so there is one sure way out: move back to where the ring "
            + "opened and let go. The window stays where it was.",
        "Esc while holding the trigger also cancels.",
    ]

    var onChoose: ((String) -> Void)?
    private(set) var rows: [RadialChoiceRow] = []
    let heading = NSTextField(labelWithString: "")
    let subheading = NSTextField(labelWithString: "")
    private let list = NSScrollView()
    private let choices = Stack()
    private let note = NSStackView()

    init(groups: [RadialEditor.Group]) {
        super.init(frame: .zero)
        boxType = .custom
        titlePosition = .noTitle
        cornerRadius = Self.radius
        fillColor = Self.fill
        borderColor = Self.edge
        contentViewMargins = .zero
        heading.font = .systemFont(ofSize: Self.titleSize, weight: .semibold)
        subheading.font = .systemFont(ofSize: Self.subtitleSize)
        subheading.textColor = .secondaryLabelColor
        let header = NSStackView(views: [heading, subheading])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = Self.headerGap
        header.edgeInsets = Self.headerInsets
        header.setHuggingPriority(.defaultHigh, for: .vertical)
        let separator = NSBox()
        separator.boxType = .separator
        setUpList(groups)
        setUpNote()
        let parts = [header, separator, list, note]
        let stack = NSStackView(views: parts)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        for part in parts {
            part.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Self.height),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func show(title: String, subtitle: String, chosen: String?) {
        heading.stringValue = title
        subheading.stringValue = subtitle
        choices.setAccessibilityLabel(title)
        list.isHidden = chosen == nil
        note.isHidden = chosen != nil
        for row in rows {
            row.isChosen = row.choice.id == chosen
        }
        if let row = rows.first(where: \.isChosen) {
            row.scrollToVisible(row.bounds)
        }
    }

    @objc
    private func choose(_ row: RadialChoiceRow) {
        onChoose?(row.choice.id)
    }

    private func setUpList(_ groups: [RadialEditor.Group]) {
        choices.orientation = .vertical
        choices.alignment = .leading
        choices.spacing = 0
        choices.edgeInsets = Self.listInsets
        choices.setAccessibilityElement(true)
        choices.setAccessibilityRole(.radioGroup)
        choices.translatesAutoresizingMaskIntoConstraints = false
        for group in groups {
            let label = NSTextField(labelWithString: group.title)
            label.font = .systemFont(ofSize: Self.groupSize, weight: .semibold)
            label.textColor = .tertiaryLabelColor
            let header = NSStackView(views: [label])
            header.edgeInsets = Self.groupInsets
            choices.addArrangedSubview(header)
            for choice in group.choices {
                let row = RadialChoiceRow(choice, target: self, action: #selector(choose))
                rows.append(row)
                choices.addArrangedSubview(row)
            }
        }
        for item in choices.arrangedSubviews {
            item.widthAnchor.constraint(
                equalTo: choices.widthAnchor, constant: -Self.listSide - Self.listSide
            ).isActive = true
        }
        list.documentView = choices
        list.drawsBackground = false
        list.hasVerticalScroller = true
        list.autohidesScrollers = true
        NSLayoutConstraint.activate([
            choices.topAnchor.constraint(equalTo: list.contentView.topAnchor),
            choices.leadingAnchor.constraint(equalTo: list.contentView.leadingAnchor),
            choices.trailingAnchor.constraint(equalTo: list.contentView.trailingAnchor),
        ])
    }

    private func setUpNote() {
        let lines = Self.notes.map { text in
            let label = NSTextField(wrappingLabelWithString: text)
            label.font = .systemFont(ofSize: Self.noteSize)
            label.textColor = .secondaryLabelColor
            return label
        }
        note.setViews(lines, in: .top)
        for line in lines {
            line.widthAnchor.constraint(
                equalTo: note.widthAnchor, constant: -Self.inset - Self.inset
            )
            .isActive = true
        }
        note.orientation = .vertical
        note.alignment = .leading
        note.spacing = Self.noteGap
        note.edgeInsets = Self.noteInsets
        note.setHuggingPriority(.defaultLow, for: .vertical)
    }
}
