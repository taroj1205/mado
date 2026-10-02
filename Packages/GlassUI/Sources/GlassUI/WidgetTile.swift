import AppKit

final class WidgetTile: NSView {
    private static let radius: CGFloat = 16
    private static let horizontal: CGFloat = 12
    private static let trackLeading: CGFloat = 10
    private static let vertical: CGFloat = 10
    private static let valueSize: CGFloat = 22
    private static let valueKern: CGFloat = -0.4
    private static let detailSize: CGFloat = 11.5
    private static let iconSize: CGFloat = 13
    private static let iconGap: CGFloat = 4
    private static let noteSize: CGFloat = 12
    private static let titleSize: CGFloat = 11
    private static let titleKern: CGFloat = 0.4
    private static let headlineSize: CGFloat = 14
    private static let requestSize: CGFloat = 13
    private static let meterGap: CGFloat = 8
    private static let insets = horizontal + horizontal
    private static let headlineBar = (fraction: 0.4, height: 18.0)
    private static let detailBar = (fraction: 0.7, height: 10.0)
    private static let fillAlpha = (dark: 0.055, light: 0.55)
    private static let edgeAlpha = (dark: 0.07, light: 0.06)
    private static let selectedFillAlpha = (dark: 0.13, light: 0.065)
    private static let selectedEdgeAlpha = (dark: 0.26, light: 0.16)
    private static let fill = tone(.white, .white, fillAlpha)
    private static let edge = tone(.white, .black, edgeAlpha)
    private static let selectedFill = tone(.white, .black, selectedFillAlpha)
    private static let selectedEdge = tone(.white, .black, selectedEdgeAlpha)

    let title = NSTextField(labelWithString: "")
    let value = NSTextField(labelWithString: "")
    let headline = NSTextField(labelWithString: "")
    let skeleton = [headlineBar, detailBar].map { bar in
        WidgetSkeleton(fraction: bar.fraction, height: bar.height)
    }
    let detail = NSTextField(labelWithString: "")
    let reason = NSTextField(labelWithString: "")
    let allow = AllowCapsule()
    let icon = NSImageView()
    let meters = NSStackView()
    let track = WidgetTrack()
    private lazy var trackPlacement = [
        track.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.trackLeading),
        track.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontal),
        track.centerYAnchor.constraint(equalTo: centerYAnchor),
    ]
    private let box = NSBox()
    private let lines = NSStackView()
    private let request = NSStackView()
    var onPress: (() -> Void)?
    var onSkip: ((WidgetGrid.Skip) -> Void)?

    var selected = false {
        didSet {
            box.fillColor = selected ? Self.selectedFill : Self.fill
            box.borderColor = selected ? Self.selectedEdge : Self.edge
            setAccessibilitySelected(selected)
        }
    }

    init() {
        super.init(frame: .zero)
        box.boxType = .custom
        box.cornerRadius = Self.radius
        box.borderWidth = 1
        box.fillColor = Self.fill
        box.borderColor = Self.edge
        box.autoresizingMask = [.width, .height]
        addSubview(box)
        arrangeLines()
        icon.symbolConfiguration = .init(pointSize: Self.iconSize, weight: .regular)
        icon.contentTintColor = .secondaryLabelColor
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)
        meters.orientation = .vertical
        meters.spacing = Self.meterGap
        meters.translatesAutoresizingMaskIntoConstraints = false
        [meters, track].forEach(addSubview)
        NSLayoutConstraint.activate([
            meters.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.horizontal),
            meters.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontal),
            meters.centerYAnchor.constraint(equalTo: centerYAnchor),
            value.trailingAnchor.constraint(
                lessThanOrEqualTo: icon.leadingAnchor, constant: -Self.iconGap),
            icon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.horizontal),
            icon.centerYAnchor.constraint(equalTo: value.centerYAnchor),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    static func tone(
        _ dark: NSColor, _ light: NSColor, _ alpha: (dark: Double, light: Double)
    ) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                ? dark.withAlphaComponent(alpha.dark) : light.withAlphaComponent(alpha.light)
        }
    }

    private func arrangeLines() {
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
        ([title, value, headline] + skeleton + [detail, request]).forEach(lines.addArrangedSubview)
        lines.orientation = .vertical
        lines.alignment = .leading
        lines.distribution = .equalSpacing
        lines.spacing = 0
        lines.edgeInsets = NSEdgeInsets(
            top: Self.vertical, left: Self.horizontal, bottom: Self.vertical,
            right: Self.horizontal)
        lines.translatesAutoresizingMaskIntoConstraints = false
        addSubview(lines)
        let width = lines.widthAnchor
        NSLayoutConstraint.activate(
            [
                lines.leadingAnchor.constraint(equalTo: leadingAnchor),
                lines.trailingAnchor.constraint(equalTo: trailingAnchor),
                lines.topAnchor.constraint(equalTo: topAnchor),
                lines.bottomAnchor.constraint(equalTo: bottomAnchor),
                request.widthAnchor.constraint(equalTo: width, constant: -Self.insets),
            ]
                + skeleton.map { bar in
                    bar.widthAnchor.constraint(
                        equalTo: width, multiplier: bar.fraction,
                        constant: -bar.fraction * Self.insets)
                })
    }

    func show(_ widget: WidgetGrid.Widget) {
        var visible: [NSView] = []
        var readings: [WidgetGrid.Meter] = []
        var symbol: String?
        switch widget.content {
        case let .value(text, note, name):
            symbol = name
            showValue(text)
            showDetail(note, size: Self.detailSize)
            visible = [value, detail]

        case let .meters(list):
            readings = list

        case let .track(playing):
            track.show(playing)

        case let .loading(name):
            showTitle(name)
            visible = [title] + skeleton

        case let .notice(name, line, note):
            showTitle(name)
            showHeadline(line, size: Self.headlineSize)
            showDetail(note, size: Self.noteSize)
            visible = [title, headline, detail]

        case let .permission(name, line, why):
            showTitle(name)
            showHeadline(line, size: Self.requestSize)
            reason.stringValue = why
            visible = [title, headline, request]
        }
        for row in lines.arrangedSubviews {
            row.isHidden = !visible.contains(row)
        }
        icon.image = symbol.flatMap { name in
            NSImage(systemSymbolName: name, accessibilityDescription: nil)
        }
        showMeters(readings)
        showTrack(widget.track != nil)
        setAccessibilityLabel(widget.spoken)
        setAccessibilityCustomActions(
            widget.track == nil
                ? []
                : [skip("Previous Track", .previous), skip("Next Track", .next)])
    }

    private func showTrack(_ shows: Bool) {
        track.isHidden = !shows
        if shows {
            NSLayoutConstraint.activate(trackPlacement)
        } else {
            NSLayoutConstraint.deactivate(trackPlacement)
        }
    }

    private func skip(_ name: String, _ skip: WidgetGrid.Skip) -> NSAccessibilityCustomAction {
        NSAccessibilityCustomAction(name: name) { [weak self] in
            self?.onSkip?(skip)
            return true
        }
    }

    private func showValue(_ text: String) {
        value.attributedStringValue = NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: Self.valueSize, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
                .kern: Self.valueKern,
            ])
    }

    private func showTitle(_ name: String) {
        title.attributedStringValue = NSAttributedString(
            string: name.localizedUppercase,
            attributes: [
                .font: NSFont.systemFont(ofSize: Self.titleSize, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor,
                .kern: Self.titleKern,
            ])
    }

    private func showHeadline(_ line: String, size: CGFloat) {
        headline.font = .systemFont(ofSize: size, weight: .semibold)
        headline.stringValue = line
    }

    private func showDetail(_ note: String, size: CGFloat) {
        detail.font = .systemFont(ofSize: size)
        detail.stringValue = note
    }

    private func showMeters(_ readings: [WidgetGrid.Meter]) {
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

    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.contains(point) ? self : nil
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        let point = track.convert(event.locationInWindow, from: nil)
        if !track.isHidden, let skip = track.skip(at: point) {
            onSkip?(skip)
        } else {
            onPress?()
        }
    }

    override func accessibilityPerformPress() -> Bool {
        onPress?()
        return true
    }
}
