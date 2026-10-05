import AppKit

final class WidgetFace: NSView {
    struct Block {
        let height: CGFloat
        var quantum: CGFloat?
        let put: (NSRect) -> Void
    }

    static let shortValue: CGFloat = 22
    static let tallValue: CGFloat = 34
    static let narrowValue: CGFloat = 30
    static let valueKern: CGFloat = -0.4
    static let detailSize: CGFloat = 11.5
    static let iconSize: CGFloat = 13
    static let tallIcon: CGFloat = 22
    static let iconGap: CGFloat = 4
    static let sectionGap: CGFloat = 14
    static let stackGap: CGFloat = 18
    static let spanHeight: CGFloat = 14
    static let detailGap: CGFloat = 1
    static let minGap: CGFloat = 6
    static let iconAspect: CGFloat = 1.6
    static let leadWidth = (medium: 88.0, wide: 104.0)
    static let shareOfMeters: CGFloat = 0.55
    static let half: CGFloat = 0.5

    let value = NSTextField(labelWithString: "")
    let detail = NSTextField(labelWithString: "")
    let icon = NSImageView()
    let span = WidgetSpan()
    let hours = WidgetHours()
    let facts = WidgetFacts()
    let divider = NSBox()
    private var spare: [WidgetGauge] = []
    private(set) var gauges: [WidgetGauge] = []
    private(set) var widget: WidgetGrid.Widget?
    private(set) var form = WidgetForm(size: .zero)
    private(set) var compact = false

    override var isFlipped: Bool { true }

    var valueSize: CGFloat {
        guard form.tall else { return Self.shortValue }
        return form.reach == .narrow ? Self.narrowValue : Self.tallValue
    }

    var iconSize: CGFloat {
        form.tall ? Self.tallIcon : Self.iconSize
    }

    var iconWidth: CGFloat {
        iconSize * Self.iconAspect
    }

    var hasSpan: Bool {
        if case .value(_, _, _, let range) = widget?.content {
            range != nil && !compact
        } else {
            false
        }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        divider.boxType = .separator
        detail.font = .systemFont(ofSize: Self.detailSize)
        detail.textColor = .secondaryLabelColor
        icon.contentTintColor = .secondaryLabelColor
        icon.imageScaling = .scaleProportionallyDown
        icon.imageAlignment = .alignRight
        for label in [value, detail] {
            label.lineBreakMode = .byTruncatingTail
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        [value, detail, icon, span, hours, facts, divider].forEach(addSubview)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    func show(_ widget: WidgetGrid.Widget, form: WidgetForm, compact: Bool) {
        self.widget = widget
        self.form = form
        self.compact = compact
        switch widget.content {
        case let .value(text, line, symbol, range):
            value.attributedStringValue = NSAttributedString(
                string: text,
                attributes: [
                    .font: NSFont.monospacedDigitSystemFont(
                        ofSize: valueSize, weight: .semibold),
                    .foregroundColor: NSColor.labelColor, .kern: Self.valueKern,
                ])
            detail.stringValue = line
            icon.image = symbol.flatMap { name in
                NSImage(systemSymbolName: name, accessibilityDescription: nil)
            }
            icon.symbolConfiguration = .init(pointSize: iconSize, weight: .regular)
            if let range {
                span.show(range)
            }

        case .meters(let list):
            showGauges(list)

        default: break
        }
        hours.show(widget.hours)
        facts.show(widget.facts)
        needsLayout = true
    }

    func showsIcon(in width: CGFloat) -> Bool {
        icon.image != nil
            && width - value.intrinsicContentSize.width - iconWidth - Self.iconGap - Self.iconGap
                >= 0
    }

    override func layout() {
        super.layout()
        let area = bounds.insetBy(dx: WidgetTile.horizontal, dy: WidgetTile.vertical)
        for view in [value, detail, icon, span, hours, facts, divider] + gauges + spare {
            view.isHidden = true
        }
        icon.imageAlignment = form.tall && form.reach == .narrow ? .alignLeft : .alignRight
        switch widget?.content {
        case .value:
            if form.tall {
                stackValue(in: area)
            } else {
                sideValue(in: area)
            }

        case .meters:
            if form.tall {
                stackMeters(in: area)
            } else {
                sideMeters(in: area)
            }

        default: break
        }
    }

    private func showGauges(_ list: [WidgetGrid.Meter]) {
        let all = gauges + spare
        while all.count < list.count, gauges.count + spare.count < list.count {
            let gauge = WidgetGauge()
            spare.append(gauge)
            addSubview(gauge)
        }
        let pool = gauges + spare
        gauges = Array(pool.prefix(list.count))
        spare = Array(pool.dropFirst(list.count))
        for (gauge, meter) in zip(gauges, list) {
            gauge.show(meter)
            gauge.style = form.tall && form.reach != .narrow ? .ring : .bar
        }
    }

    func place(_ blocks: [Block], in area: NSRect, gap: CGFloat) {
        var kept: [Block] = []
        var used: CGFloat = 0
        for block in blocks {
            let spacing = kept.isEmpty ? 0 : Self.minGap
            var height = block.height
            if used + spacing + height > area.height, let quantum = block.quantum {
                height = floor((area.height - used - spacing) / quantum) * quantum
            }
            guard height > 0, used + spacing + height <= area.height else { continue }
            kept.append(Block(height: height, quantum: block.quantum, put: block.put))
            used += spacing + height
        }
        let heights = kept.reduce(0) { $0 + $1.height }
        let step = kept.count > 1 ? min((area.height - heights) / CGFloat(kept.count - 1), gap) : 0
        var top =
            area.minY + (area.height - heights - step * CGFloat(max(kept.count - 1, 0))) * Self.half
        for block in kept {
            block.put(NSRect(x: area.minX, y: top, width: area.width, height: block.height))
            top += block.height + step
        }
    }

    func put(_ views: [NSView: NSRect]) {
        for (view, frame) in views {
            view.frame = frame
            view.isHidden = false
        }
    }
}
