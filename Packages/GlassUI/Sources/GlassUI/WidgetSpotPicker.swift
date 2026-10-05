import AppKit

final class WidgetSpotPicker: NSView {
    static let gap: CGFloat = 8

    private static let width: CGFloat = 300
    private static let height: CGFloat = 248
    private static let side: CGFloat = 16
    private static let titleTop: CGFloat = 12
    private static let mapTop: CGFloat = 27
    private static let mapHeight: CGFloat = 164
    private static let panelMark = (width: 128.0, height: 86.0)
    private static let shelf = (top: 18.0, step: 40.0)
    private static let rail = (offset: 92.0, middle: 81.0, step: 27.0)
    private static let titleSize: CGFloat = 12
    private static let labelSize: CGFloat = 13
    private static let dot: CGFloat = 8
    private static let footerGap: CGFloat = 8
    private static let footerTrailing: CGFloat = 10
    private static let keyGap: CGFloat = 3
    private static let keyRadius: CGFloat = 5
    private static let keySize: CGFloat = 20
    private static let half: CGFloat = 0.5

    static var size: NSSize { NSSize(width: width, height: height) }

    let glass = GlassView(shape: .rounded(ActionPanel.radius))
    let title = NSTextField(labelWithString: "")
    let label = NSTextField(labelWithString: "")
    private let marker = NSView()
    private(set) var marks: [WidgetSpotMark] = []
    var onPick: ((WidgetGrid.Spot) -> Void)?

    var value: WidgetGrid.Spot {
        didSet { show() }
    }

    private var hover: WidgetGrid.Spot? {
        didSet { show() }
    }

    override var isFlipped: Bool { true }

    init(moving name: String, from spot: WidgetGrid.Spot) {
        value = spot
        super.init(frame: NSRect(origin: .zero, size: Self.size))
        title.stringValue = "Move \(name)"
        title.font = .systemFont(ofSize: Self.titleSize, weight: .semibold)
        title.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: Self.labelSize, weight: .semibold)
        marker.wantsLayer = true
        marker.layer?.cornerRadius = Self.dot * Self.half
        arrange()
        glass.sheen.isHidden = true
        glass.translatesAutoresizingMaskIntoConstraints = false
        glass.contentView = self
        setAccessibilityElement(true)
        setAccessibilityRole(.radioGroup)
        setAccessibilityLabel(title.stringValue)
        show()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    private static func centre(of spot: WidgetGrid.Spot) -> NSPoint {
        let middle = width * half
        let shift = { (step: CGFloat) -> CGFloat in
            switch spot.anchor {
            case .start: -step
            case .middle: 0
            case .end: step
            }
        }
        return switch spot.side {
        case .panel: NSPoint(x: middle, y: rail.middle)
        case .above: NSPoint(x: middle + shift(shelf.step), y: shelf.top)
        case .left: NSPoint(x: middle - rail.offset, y: rail.middle + shift(rail.step))
        case .right: NSPoint(x: middle + rail.offset, y: rail.middle + shift(rail.step))
        }
    }

    func contains(_ point: NSPoint) -> Bool {
        unsafe glass.superview != nil && glass.convert(glass.bounds, to: nil).contains(point)
    }

    func dismiss() {
        glass.removeFromSuperview()
        glass.contentView = nil
    }

    func step(_ heading: WidgetGrid.Heading) {
        value = value.neighbour(toward: heading) ?? value
    }

    private func arrange() {
        marks = WidgetGrid.Spot.presets.map(WidgetSpotMark.init)
        for mark in marks {
            let centre = Self.centre(of: mark.spot)
            let extent =
                mark.spot == .panel
                ? NSSize(width: Self.panelMark.width, height: Self.panelMark.height)
                : NSSize(width: WidgetSpotMark.target, height: WidgetSpotMark.target)
            mark.frame = NSRect(
                x: centre.x - extent.width * Self.half,
                y: Self.mapTop + centre.y - extent.height * Self.half, width: extent.width,
                height: extent.height)
            mark.onPick = { [weak self] spot in self?.onPick?(spot) }
            mark.onHover = { [weak self] spot in self?.hover = spot }
            addSubview(mark)
        }
        title.frame.origin = NSPoint(x: Self.side, y: Self.titleTop)
        title.sizeToFit()
        addSubview(title)
        arrangeFooter()
    }

    private func arrangeFooter() {
        let line = NSBox()
        line.boxType = .separator
        line.frame = NSRect(x: 0, y: Self.mapTop + Self.mapHeight, width: Self.width, height: 1)
        let keys = NSStackView(
            views: ["←↑→↓", "↵"].map { Keycap($0, radius: Self.keyRadius, size: Self.keySize) })
        keys.spacing = Self.keyGap
        let footer = NSStackView(views: [marker, label, NSView(), keys])
        footer.spacing = Self.footerGap
        footer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(line)
        addSubview(footer)
        NSLayoutConstraint.activate([
            marker.widthAnchor.constraint(equalToConstant: Self.dot),
            marker.heightAnchor.constraint(equalToConstant: Self.dot),
            footer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Self.side),
            footer.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -Self.footerTrailing),
            footer.topAnchor.constraint(equalTo: line.bottomAnchor),
            footer.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func show() {
        let shown = hover ?? value
        for mark in marks {
            mark.isOn = mark.spot == value.preset
            mark.isHot = mark.spot == hover
        }
        label.stringValue = shown.title
        marker.layer?.backgroundColor =
            (shown == value ? NSColor.controlAccentColor : .secondaryLabelColor).cgColor
        setAccessibilityValue(value.title)
    }
}
