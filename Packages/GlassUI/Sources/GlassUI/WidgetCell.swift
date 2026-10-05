import AppKit

final class WidgetCell: NSTableCellView {
    static let id = NSUserInterfaceItemIdentifier("widget")
    private static let side: CGFloat = 20
    private static let padding: CGFloat = 18
    private static let messageHeight: CGFloat = 76
    private static let meterHeight: CGFloat = 22
    private static let meterGap: CGFloat = 14
    private static let lineHeight: CGFloat = 18
    private static let lineGap: CGFloat = 6
    private static let lineBar: CGFloat = 4
    private static let lineBarHeight: CGFloat = 16
    private static let lineBarRadius: CGFloat = 2
    private static let timeWidth: CGFloat = 62
    private static let timeSize: CGFloat = 12.5
    private static let titleSize: CGFloat = 14
    private static let noteSize: CGFloat = 12
    private static let iconSize: CGFloat = 26
    private static let valueSize: CGFloat = 32
    private static let valueKern: CGFloat = -0.6
    private static let iconGap: CGFloat = 10
    private static let detailGap: CGFloat = 6
    private static let hourWidth: CGFloat = 40
    private static let hourGap: CGFloat = 18
    private static let hourSymbolSize: CGFloat = 16
    private static let hourTextSize: CGFloat = 11
    private static let hourValueSize: CGFloat = 13
    private static let hourSpacing: CGFloat = 6
    private static let forecastGap: CGFloat = 16
    private static let lineSpacing: CGFloat = 12

    private var body: NSView?

    override init(frame: NSRect) {
        super.init(frame: frame)
        identifier = Self.id
        setAccessibilityChildren([])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    static func height(for card: ResultList.WidgetCard) -> CGFloat {
        switch card.body {
        case .forecast:
            ResultList.answerHeight

        case .message:
            messageHeight

        case .meters(let meters):
            list(meters.count, of: meterHeight, gap: meterGap)

        case .events(let lines):
            list(lines.count, of: lineHeight, gap: lineGap)
        }
    }

    private static func list(_ count: Int, of height: CGFloat, gap: CGFloat) -> CGFloat {
        let rows = CGFloat(max(count, 1))
        return padding + rows * height + (rows - 1) * gap + padding
    }

    private static func label(
        _ text: String, size: CGFloat, weight: NSFont.Weight = .regular,
        colour: NSColor = .labelColor, digits: Bool = false
    ) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font =
            digits
            ? .monospacedDigitSystemFont(ofSize: size, weight: weight)
            : .systemFont(ofSize: size, weight: weight)
        label.textColor = colour
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    private static func symbol(_ name: String, size: CGFloat) -> NSImageView {
        let view = NSImageView()
        view.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        view.symbolConfiguration = .init(pointSize: size, weight: .regular)
        view.contentTintColor = .labelColor
        view.setContentHuggingPriority(.required, for: .horizontal)
        return view
    }

    func show(_ card: ResultList.WidgetCard) {
        body?.removeFromSuperview()
        let view = makeBody(of: card.body)
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        let vertical: NSLayoutConstraint
        switch card.body {
        case .meters, .events:
            vertical = view.topAnchor.constraint(equalTo: topAnchor, constant: Self.padding)

        case .forecast, .message:
            vertical = view.centerYAnchor.constraint(equalTo: centerYAnchor)
        }
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.side),
            view.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.side),
            vertical,
        ])
        body = view
        setAccessibilityLabel(card.spoken)
    }

    private func makeBody(of body: ResultList.WidgetBody) -> NSView {
        switch body {
        case let .forecast(symbol, value, detail, hours):
            forecast(symbol: symbol, value: value, detail: detail, hours: hours)

        case .meters(let meters):
            meterList(meters)

        case .events(let lines):
            lineList(lines)

        case let .message(headline, detail):
            message(headline: headline, detail: detail)
        }
    }

    private func forecast(
        symbol: String, value: String, detail: String, hours: [ResultList.WidgetHour]
    ) -> NSView {
        let temperature = Self.label(value, size: Self.valueSize, weight: .semibold, digits: true)
        temperature.attributedStringValue = NSAttributedString(
            string: value,
            attributes: [
                .font: temperature.font as Any, .kern: Self.valueKern,
                .foregroundColor: NSColor.labelColor,
            ])
        let headline = NSStackView(views: [Self.symbol(symbol, size: Self.iconSize), temperature])
        headline.spacing = Self.iconGap
        let summary = NSStackView(views: [
            headline, Self.label(detail, size: Self.noteSize, colour: .secondaryLabelColor),
        ])
        summary.orientation = .vertical
        summary.alignment = .leading
        summary.spacing = Self.detailGap
        summary.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let columns = NSStackView(views: hours.map(hourColumn))
        columns.spacing = Self.hourGap
        columns.setContentHuggingPriority(.required, for: .horizontal)
        columns.setContentCompressionResistancePriority(.required, for: .horizontal)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.init(1), for: .horizontal)
        let row = NSStackView(views: [summary, spacer, columns])
        row.spacing = Self.forecastGap
        row.distribution = .fill
        return row
    }

    private func hourColumn(_ hour: ResultList.WidgetHour) -> NSView {
        let stack = NSStackView(views: [
            Self.label(hour.label, size: Self.hourTextSize, colour: .secondaryLabelColor),
            Self.symbol(hour.symbol, size: Self.hourSymbolSize),
            Self.label(hour.value, size: Self.hourValueSize, weight: .semibold, digits: true),
        ])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = Self.hourSpacing
        stack.widthAnchor.constraint(equalToConstant: Self.hourWidth).isActive = true
        return stack
    }

    private func meterList(_ meters: [WidgetGrid.Meter]) -> NSView {
        let views = meters.map { meter in
            let view = WidgetMeter()
            view.show(meter)
            return view
        }
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.meterGap
        NSLayoutConstraint.activate(
            views.map { $0.widthAnchor.constraint(equalTo: stack.widthAnchor) })
        return stack
    }

    private func lineList(_ lines: [ResultList.WidgetLine]) -> NSView {
        let stack = NSStackView(views: lines.map(line))
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.lineGap
        return stack
    }

    private func line(_ line: ResultList.WidgetLine) -> NSView {
        let time = Self.label(
            line.time, size: Self.timeSize, colour: .secondaryLabelColor, digits: true)
        let bar = NSBox()
        bar.boxType = .custom
        bar.borderWidth = 0
        bar.cornerRadius = Self.lineBarRadius
        bar.fillColor = line.colour
        let title = Self.label(line.title, size: Self.titleSize, weight: .medium)
        let row = NSStackView(views: [time, bar, title])
        row.spacing = Self.lineSpacing
        NSLayoutConstraint.activate([
            time.widthAnchor.constraint(equalToConstant: Self.timeWidth),
            bar.widthAnchor.constraint(equalToConstant: Self.lineBar),
            bar.heightAnchor.constraint(equalToConstant: Self.lineBarHeight),
            row.heightAnchor.constraint(equalToConstant: Self.lineHeight),
        ])
        return row
    }

    private func message(headline: String, detail: String) -> NSView {
        let title = Self.label(headline, size: Self.titleSize, weight: .medium)
        let note = Self.label(detail, size: Self.noteSize, colour: .secondaryLabelColor)
        note.isHidden = detail.isEmpty
        let stack = NSStackView(views: [title, note])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Self.detailGap
        return stack
    }
}
