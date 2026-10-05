import AppKit

extension WidgetFace {
    func sideMeters(in area: NSRect) {
        let showsFacts = form.reach == .wide && widget?.facts.isEmpty == false
        let lead =
            showsFacts
            ? NSRect(
                x: area.minX, y: area.minY, width: area.width * Self.shareOfMeters,
                height: area.height) : area
        placeGauges(in: lead)
        guard showsFacts else { return }
        let rest = NSRect(
            x: lead.maxX + Self.sectionGap, y: area.minY,
            width: area.maxX - lead.maxX - Self.sectionGap, height: area.height)
        put([
            divider: NSRect(
                x: lead.maxX + Self.sectionGap * Self.half, y: area.minY, width: 1,
                height: area.height),
            facts: rest,
        ])
    }

    func stackMeters(in area: NSRect) {
        let narrow = form.reach == .narrow
        var blocks =
            narrow
            ? gauges.map { gauge in
                Block(height: WidgetGauge.height(of: .bar)) { frame in
                    gauge.frame = frame
                    gauge.isHidden = false
                }
            }
            : [
                Block(height: WidgetGauge.height(of: .ring)) { [self] frame in
                    placeGauges(in: frame)
                }
            ]
        if let widget, !widget.facts.isEmpty {
            blocks.append(
                Block(
                    height: WidgetFacts.height(of: widget.facts.count, forWidth: area.width),
                    quantum: WidgetFacts.rowHeight
                ) { [facts] frame in
                    facts.frame = frame
                    facts.isHidden = false
                })
        }
        place(blocks, in: area, gap: Self.stackGap)
    }

    private func placeGauges(in rect: NSRect) {
        guard let first = gauges.first else { return }
        let width =
            (rect.width - CGFloat(gauges.count - 1) * Self.sectionGap)
            / CGFloat(gauges.count)
        let height = WidgetGauge.height(of: first.style)
        for (index, gauge) in gauges.enumerated() {
            put([
                gauge: NSRect(
                    x: rect.minX + CGFloat(index) * (width + Self.sectionGap),
                    y: rect.midY - height * Self.half, width: width, height: height)
            ])
        }
    }
}
