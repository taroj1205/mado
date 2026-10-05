public import AppCore
public import AppKit

final class CalendarPane: NSView {
    static let listWidth: CGFloat = 400
    private static let top: CGFloat = 18
    private static let side: CGFloat = 20
    private static let badgeSize: CGFloat = 11
    private static let badgeKern: CGFloat = 0.5
    private static let titleSize: CGFloat = 20
    private static let titleKern: CGFloat = -0.3
    private static let detailSize: CGFloat = 12.5
    private static let monthSize: CGFloat = 13
    private static let badgeGap: CGFloat = 4
    private static let titleGap: CGFloat = 2
    private static let detailGap: CGFloat = 18
    private static let monthGap: CGFloat = 10

    let badge = NSTextField(labelWithString: "")
    let title = NSTextField(labelWithString: "")
    let detail = NSTextField(labelWithString: "")
    let monthTitle = NSTextField(labelWithString: "")
    let grid = MonthGrid()

    override init(frame: NSRect) {
        super.init(frame: frame)
        isHidden = true
        detail.font = .systemFont(ofSize: Self.detailSize)
        detail.textColor = .secondaryLabelColor
        for label in [badge, title, detail, monthTitle] {
            label.lineBreakMode = .byTruncatingTail
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        let stack = NSStackView(views: [badge, title, detail, monthTitle, grid])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
        stack.setCustomSpacing(Self.badgeGap, after: badge)
        stack.setCustomSpacing(Self.titleGap, after: title)
        stack.setCustomSpacing(Self.detailGap, after: detail)
        stack.setCustomSpacing(Self.monthGap, after: monthTitle)
        layout(stack)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private func layout(_ stack: NSStackView) {
        let divider = NSBox()
        divider.boxType = .separator
        for view in [divider, stack] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            divider.topAnchor.constraint(equalTo: topAnchor),
            divider.bottomAnchor.constraint(equalTo: bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: Self.top),
            stack.leadingAnchor.constraint(equalTo: divider.trailingAnchor, constant: Self.side),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.side),
            grid.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    func show(_ shown: LauncherView.CalendarMonth?) {
        isHidden = shown == nil
        guard let shown else { return }
        let month = shown.month
        badge.attributedStringValue = NSAttributedString(
            string: month.badge.uppercased(),
            attributes: [
                .font: NSFont.systemFont(ofSize: Self.badgeSize, weight: .semibold),
                .foregroundColor: NSColor.controlAccentColor, .kern: Self.badgeKern,
            ])
        title.attributedStringValue = NSAttributedString(
            string: month.heading,
            attributes: [
                .font: NSFont.systemFont(ofSize: Self.titleSize, weight: .semibold),
                .foregroundColor: NSColor.labelColor, .kern: Self.titleKern,
            ])
        detail.stringValue = month.detail
        let name = NSMutableAttributedString(
            string: month.name,
            attributes: [
                .font: NSFont.systemFont(ofSize: Self.monthSize, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
            ])
        name.append(
            NSAttributedString(
                string: " \(month.year)",
                attributes: [
                    .font: NSFont.systemFont(ofSize: Self.monthSize),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ]))
        monthTitle.attributedStringValue = name
        grid.show(shown)
    }
}

extension LauncherView {
    public struct CalendarMonth: Sendable, Equatable {
        public let month: AgendaMonth
        public let colours: [String: NSColor]

        public init(month: AgendaMonth, colours: [String: NSColor]) {
            self.month = month
            self.colours = colours
        }
    }
}
