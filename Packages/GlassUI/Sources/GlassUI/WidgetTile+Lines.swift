import AppKit

extension WidgetTile {
    private static let valueSize: CGFloat = 22
    private static let valueKern: CGFloat = -0.4
    private static let titleSize: CGFloat = 11
    private static let titleKern: CGFloat = 0.4
    private static let detailSize: CGFloat = 11.5
    private static let headlineSize: CGFloat = 14
    private static let requestSize: CGFloat = 13
    private static let countdownGap: CGFloat = 4
    private static let dotSize: CGFloat = 8
    private static let dotGap: CGFloat = 7
    private static let half: CGFloat = 0.5
    private static let doubleClick = 2

    func pressForAccessibility() {
        onPress?()
        onOpen?()
    }

    func openIfAsked(by event: NSEvent) {
        let point = allow.convert(event.locationInWindow, from: nil)
        let onAllow = !allow.isHiddenOrHasHiddenAncestor && allow.bounds.contains(point)
        if opensOnSingleClick || event.clickCount == Self.doubleClick || onAllow {
            onOpen?()
        }
    }

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

    func arrangeCalendar() {
        countdown.font = .systemFont(ofSize: Self.titleSize, weight: .medium)
        countdown.textColor = .secondaryLabelColor
        countdown.translatesAutoresizingMaskIntoConstraints = false
        [countdown, month].forEach(addSubview)
        NSLayoutConstraint.activate([
            countdown.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -Self.horizontal),
            countdown.firstBaselineAnchor.constraint(equalTo: title.firstBaselineAnchor),
            title.trailingAnchor.constraint(
                lessThanOrEqualTo: countdown.leadingAnchor, constant: -Self.countdownGap),
            month.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontal),
            month.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontal),
            month.topAnchor.constraint(equalTo: topAnchor, constant: Self.vertical),
            month.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.vertical),
        ])
    }

    func showLines(of content: WidgetGrid.Content) -> [NSView] {
        countdown.stringValue = ""
        showMonth(of: content)
        switch content {
        case let .value(text, line, _, range):
            showValue(text)
            showDetail(line, size: Self.detailSize)
            guard let range, !compact else { return [value, detail] }
            span.show(range)
            return [value, detail, span]

        case .meters, .track, .verse, .month:
            return []

        case let .event(name, next):
            showTitle(name)
            countdown.stringValue = next.countdown
            showEvent(next)
            showDetail(next.detail, size: Self.noteSize)
            return [title, headline, detail]

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

    func showMeters(_ readings: [WidgetGrid.Meter]) {
        if meters.arrangedSubviews.count != readings.count {
            meters.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for _ in readings {
                let meter = WidgetMeter()
                meters.addArrangedSubview(meter)
                meter.widthAnchor.constraint(equalTo: meters.widthAnchor).isActive = true
            }
        }
        for (view, meter) in zip(meters.arrangedSubviews, readings) {
            (view as? WidgetMeter)?.show(meter)
        }
    }

    private func showMonth(of content: WidgetGrid.Content) {
        guard case .month(let grid) = content else {
            month.isHidden = true
            return
        }
        month.show(grid)
        month.isHidden = false
    }

    private func showEvent(_ next: WidgetGrid.Event) {
        let font = NSFont.systemFont(ofSize: Self.headlineSize, weight: .semibold)
        let dot = NSImage(
            size: NSSize(width: Self.dotSize + Self.dotGap, height: Self.dotSize), flipped: false
        ) { _ in
            next.colour.setFill()
            NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: Self.dotSize, height: Self.dotSize))
                .fill()
            return true
        }
        let attachment = NSTextAttachment()
        attachment.image = dot
        attachment.bounds = NSRect(
            origin: NSPoint(x: 0, y: (font.capHeight - Self.dotSize) * Self.half), size: dot.size)
        let line = NSMutableAttributedString(attachment: attachment)
        line.append(NSAttributedString(string: next.title))
        line.addAttributes(
            [.font: font, .foregroundColor: NSColor.labelColor],
            range: NSRange(location: 0, length: line.length))
        headline.attributedStringValue = line
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
