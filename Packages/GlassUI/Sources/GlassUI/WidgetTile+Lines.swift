import AppKit

extension WidgetTile {
    private static let valueSize: CGFloat = 22
    private static let valueKern: CGFloat = -0.4
    private static let titleSize: CGFloat = 11
    private static let titleKern: CGFloat = 0.4
    private static let detailSize: CGFloat = 11.5
    private static let headlineSize: CGFloat = 14
    private static let requestSize: CGFloat = 13

    func arrangeLines() {
        reason.font = .systemFont(ofSize: Self.noteSize)
        detail.textColor = .secondaryLabelColor
        reason.textColor = .secondaryLabelColor
        for label in [title, value, headline, detail, reason] {
            label.lineBreakMode = .byTruncatingTail
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        reason.setContentHuggingPriority(.defaultLow, for: .horizontal)
        [reason, allow].forEach(request.addArrangedSubview)
        request.distribution = .fill
        request.spacing = 0
        ([title, value, headline] + skeleton + [detail, span, request])
            .forEach(lines.addArrangedSubview)
        lines.orientation = .vertical
        lines.alignment = .leading
        lines.distribution = .equalSpacing
        lines.spacing = 0
        lines.translatesAutoresizingMaskIntoConstraints = false
        addSubview(lines)
        let width = lines.widthAnchor
        NSLayoutConstraint.activate(
            [
                lines.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontal),
                lines.trailingAnchor.constraint(
                    equalTo: trailingAnchor, constant: -Self.horizontal),
                lines.topAnchor.constraint(equalTo: topAnchor, constant: Self.vertical),
                lines.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.vertical),
                request.widthAnchor.constraint(equalTo: width),
                span.widthAnchor.constraint(equalTo: width),
            ]
                + skeleton.map { bar in
                    bar.widthAnchor.constraint(equalTo: width, multiplier: bar.fraction)
                })
    }

    func showLines(of content: WidgetGrid.Content) -> [NSView] {
        switch content {
        case let .value(text, line, _, range):
            showValue(text)
            showDetail(line, size: Self.detailSize)
            guard let range, !compact else { return [value, detail] }
            span.show(range)
            return [value, detail, span]

        case .meters, .track:
            return []

        case let .loading(name):
            showTitle(name)
            return [title] + skeleton

        case let .notice(name, line, note):
            showTitle(name)
            showHeadline(line, size: Self.headlineSize)
            showDetail(note, size: Self.noteSize)
            return [title, headline, detail]

        case let .permission(name, line, why):
            showTitle(name)
            showHeadline(line, size: Self.requestSize)
            reason.stringValue = why
            return [title, headline, request]

        case let .unavailable(name, summary):
            showTitle(name)
            showHeadline(summary, size: Self.requestSize)
            return [title, headline]
        }
    }

    func showValue(_ text: String) {
        value.attributedStringValue = NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: Self.valueSize, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
                .kern: Self.valueKern,
            ])
    }

    func showTitle(_ name: String) {
        title.attributedStringValue = NSAttributedString(
            string: name.localizedUppercase,
            attributes: [
                .font: NSFont.systemFont(ofSize: Self.titleSize, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor,
                .kern: Self.titleKern,
            ])
    }

    func showHeadline(_ line: String, size: CGFloat) {
        headline.font = .systemFont(ofSize: size, weight: .semibold)
        headline.stringValue = line
    }

    func showDetail(_ note: String, size: CGFloat) {
        detail.font = .systemFont(ofSize: size)
        detail.stringValue = note
    }
}
