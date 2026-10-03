import AppKit

final class WidgetTile: NSView {
    private typealias Look = (fill: NSColor, edge: NSColor)

    static let radius: CGFloat = 16
    static let horizontal: CGFloat = 12
    private static let trackLeading: CGFloat = 10
    static let vertical: CGFloat = 10
    static let noteSize: CGFloat = 12
    private static let detailSize: CGFloat = 11.5
    private static let iconSize: CGFloat = 13
    private static let iconGap: CGFloat = 4
    private static let headlineSize: CGFloat = 14
    private static let requestSize: CGFloat = 13
    private static let meterGap: CGFloat = 8
    private static let headlineBar = (fraction: 0.4, height: 18.0)
    private static let detailBar = (fraction: 0.7, height: 10.0)
    private static let fillAlpha = (dark: 0.055, light: 0.55)
    private static let edgeAlpha = (dark: 0.07, light: 0.06)
    private static let selectedFillAlpha = (dark: 0.13, light: 0.065)
    private static let selectedEdgeAlpha = (dark: 0.26, light: 0.16)
    static let fill = tone(.white, .white, fillAlpha)
    static let edge = tone(.white, .black, edgeAlpha)
    static let selectedFill = tone(.white, .black, selectedFillAlpha)
    static let selectedEdge = tone(.white, .black, selectedEdgeAlpha)
    private static let floatingSelectedAlpha = (dark: 0.34, light: 0.80)
    private static let floatingSelectedTint = (red: 0.55, green: 0.55, blue: 0.63)
    private static let floatingSelectedFill = tone(
        NSColor(
            srgbRed: floatingSelectedTint.red, green: floatingSelectedTint.green,
            blue: floatingSelectedTint.blue, alpha: 1),
        .white, floatingSelectedAlpha)
    private static let inlineLooks: (resting: Look, picked: Look) = (
        (fill, edge), (selectedFill, selectedEdge)
    )
    private static let floatingLooks: (resting: Look, picked: Look) = (
        (.clear, .clear), (floatingSelectedFill, selectedEdge)
    )

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
    let lines = NSStackView()
    let request = NSStackView()
    private let looks: (resting: Look, picked: Look)
    var onPress: (() -> Void)?
    var onSkip: ((WidgetGrid.Skip) -> Void)?

    var selected = false {
        didSet { paint() }
    }

    init(floating: Bool) {
        looks = floating ? Self.floatingLooks : Self.inlineLooks
        super.init(frame: .zero)
        box.boxType = .custom
        box.cornerRadius = Self.radius
        box.borderWidth = 1
        paint()
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

    private func paint() {
        let look = selected ? looks.picked : looks.resting
        box.fillColor = look.fill
        box.borderColor = look.edge
        setAccessibilitySelected(selected)
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
