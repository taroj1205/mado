public import AppCore
public import AppKit

final class CalendarPane: NSView {
    static let width: CGFloat = 300
    private static let side: CGFloat = 16
    private static let monthSize: CGFloat = 13

    let monthTitle = NSTextField(labelWithString: "")
    let grid = MonthGrid()

    override init(frame: NSRect) {
        super.init(frame: frame)
        isHidden = true
        monthTitle.lineBreakMode = .byTruncatingTail
        monthTitle.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let divider = NSBox()
        divider.boxType = .separator
        for view in [divider, monthTitle, grid] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            divider.topAnchor.constraint(equalTo: topAnchor),
            divider.bottomAnchor.constraint(equalTo: bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),
            monthTitle.leadingAnchor.constraint(
                equalTo: divider.trailingAnchor, constant: Self.side),
            monthTitle.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor, constant: -Self.side),
            monthTitle.bottomAnchor.constraint(
                equalTo: topAnchor, constant: ResultList.headerHeight - ResultList.headerBottom),
            grid.topAnchor.constraint(equalTo: topAnchor, constant: ResultList.headerHeight),
            grid.leadingAnchor.constraint(equalTo: monthTitle.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.side),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func show(_ shown: LauncherView.CalendarMonth?) {
        isHidden = shown == nil
        guard let shown else { return }
        let month = shown.month
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
