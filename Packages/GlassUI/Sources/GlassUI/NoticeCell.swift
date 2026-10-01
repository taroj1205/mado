import AppKit

final class NoticeCell: NSTableCellView {
    static let id = NSUserInterfaceItemIdentifier("notice")
    private static let topInset: CGFloat = 26
    private static let sideInset: CGFloat = 12
    private static let gap: CGFloat = 6
    private static let titleSize: CGFloat = 15
    private static let detailSize: CGFloat = 13

    let title = NSTextField(labelWithString: "")
    let detail = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)
        identifier = Self.id
        title.font = .systemFont(ofSize: Self.titleSize, weight: .semibold)
        detail.font = .systemFont(ofSize: Self.detailSize)
        detail.textColor = .secondaryLabelColor
        for label in [title, detail] {
            label.alignment = .center
            label.lineBreakMode = .byTruncatingTail
            label.translatesAutoresizingMaskIntoConstraints = false
            addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: centerXAnchor),
                label.leadingAnchor.constraint(
                    greaterThanOrEqualTo: leadingAnchor, constant: Self.sideInset),
            ])
        }
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: topAnchor, constant: Self.topInset),
            detail.topAnchor.constraint(equalTo: title.bottomAnchor, constant: Self.gap),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func show(_ notice: ResultList.Notice) {
        title.stringValue = notice.title
        detail.stringValue = notice.detail
    }
}
