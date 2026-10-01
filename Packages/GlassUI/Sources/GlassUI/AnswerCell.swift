import AppKit

final class AnswerCell: NSTableCellView {
    static let id = NSUserInterfaceItemIdentifier("answer")
    static let radius: CGFloat = 12
    static let columnWidth: CGFloat = 300
    private static let sideInset: CGFloat = 20
    private static let gap: CGFloat = 8
    private static let detailSize: CGFloat = 12
    private static let arrowSize: CGFloat = 14
    private static let expressionSize: CGFloat = 26
    private static let resultSize: CGFloat = 32
    private static let expressionFont = NSFont.systemFont(ofSize: expressionSize, weight: .semibold)
    private static let resultFont = NSFont.systemFont(ofSize: resultSize, weight: .semibold)
    private static let expressionKern: CGFloat = -0.4
    private static let resultKern: CGFloat = -0.6

    let expression = NSTextField(labelWithString: "")
    let expressionDetail = NSTextField(labelWithString: "")
    let result = NSTextField(labelWithString: "")
    let resultDetail = NSTextField(labelWithString: "")
    let arrow = NSImageView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        identifier = Self.id
        for detail in [expressionDetail, resultDetail] {
            detail.font = .systemFont(ofSize: Self.detailSize)
            detail.textColor = .secondaryLabelColor
        }
        arrow.image = NSImage(systemSymbolName: "arrow.right", accessibilityDescription: nil)
        arrow.symbolConfiguration = .init(pointSize: Self.arrowSize, weight: .medium)
        arrow.contentTintColor = .secondaryLabelColor
        arrow.translatesAutoresizingMaskIntoConstraints = false
        addSubview(arrow)
        let left = column(expression, expressionDetail)
        let right = column(result, resultDetail)
        NSLayoutConstraint.activate([
            arrow.centerXAnchor.constraint(equalTo: centerXAnchor),
            arrow.centerYAnchor.constraint(equalTo: centerYAnchor),
            left.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.sideInset),
            right.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.sideInset),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func text(_ string: String, font: NSFont, kern: CGFloat) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        return NSAttributedString(
            string: string,
            attributes: [
                .font: font, .kern: kern, .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraph,
            ])
    }

    func show(_ item: ResultList.Item) {
        expression.attributedStringValue = Self.text(
            item.title, font: Self.expressionFont, kern: Self.expressionKern)
        expressionDetail.stringValue = item.subtitle
        result.attributedStringValue = Self.text(
            item.answer?.value ?? "", font: Self.resultFont, kern: Self.resultKern)
        resultDetail.stringValue = item.answer?.detail ?? ""
        setAccessibilityLabel("\(item.title) equals \(item.answer?.value ?? "")")
    }

    private func column(_ title: NSTextField, _ detail: NSTextField) -> NSStackView {
        for label in [title, detail] {
            label.alignment = .center
            label.lineBreakMode = .byTruncatingTail
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        let stack = NSStackView(views: [title, detail])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = Self.gap
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.widthAnchor.constraint(equalToConstant: Self.columnWidth),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            title.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor),
            detail.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor),
        ])
        return stack
    }
}
