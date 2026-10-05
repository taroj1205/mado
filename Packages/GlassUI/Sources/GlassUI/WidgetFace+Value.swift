import AppKit

extension WidgetFace {
    func sideValue(in area: NSRect) {
        let aside = widget.map { !$0.hours.isEmpty || !$0.facts.isEmpty } ?? false
        let lead =
            aside
            ? NSRect(
                x: area.minX, y: area.minY,
                width: form.reach == .wide ? Self.leadWidth.wide : Self.leadWidth.medium,
                height: area.height) : area
        placeHeader(in: lead)
        guard aside else { return }
        let rest = NSRect(
            x: lead.maxX + Self.sectionGap, y: area.minY,
            width: area.maxX - lead.maxX - Self.sectionGap, height: area.height)
        put([
            divider: NSRect(
                x: lead.maxX + Self.sectionGap * Self.half, y: area.minY, width: 1,
                height: area.height)
        ])
        if widget?.hours.isEmpty == false {
            put([hours: rest])
        } else {
            put([facts: rest])
        }
    }

    func stackValue(in area: NSRect) {
        let width = area.width
        let beside = form.reach == .wide && widget?.hours.isEmpty == false
        var blocks = [header(forWidth: beside ? width * Self.shareOfMeters : width, beside: beside)]
        if hasSpan {
            blocks.append(
                Block(height: Self.spanHeight) { [span] frame in
                    span.frame = frame
                    span.isHidden = false
                })
        }
        if let widget {
            blocks += asides(of: widget, width: width, skippingFacts: beside)
        }
        place(blocks, in: area, gap: Self.stackGap)
    }

    func asides(of widget: WidgetGrid.Widget, width: CGFloat, skippingFacts: Bool) -> [Block] {
        var blocks: [Block] = []
        if !widget.hours.isEmpty {
            let height = WidgetHours.height(of: widget.hours.count, forWidth: width)
            blocks.append(
                block(of: hours, height: height, quantum: WidgetHours.quantum(forWidth: width)))
        }
        if !widget.facts.isEmpty, !skippingFacts {
            let height = WidgetFacts.height(of: widget.facts.count, forWidth: width)
            blocks.append(block(of: facts, height: height, quantum: WidgetFacts.rowHeight))
        }
        return blocks
    }

    private func block(of view: NSView, height: CGFloat, quantum: CGFloat?) -> Block {
        Block(height: height, quantum: quantum) { frame in
            view.frame = frame
            view.isHidden = false
        }
    }

    private func header(forWidth width: CGFloat, beside: Bool) -> Block {
        let valueHeight = value.intrinsicContentSize.height
        let detailHeight = detail.intrinsicContentSize.height
        let stacked = form.reach == .narrow
        let iconRow = stacked && icon.image != nil ? iconSize + Self.detailGap : 0
        let inline = !stacked && showsIcon(in: width)
        let height = iconRow + valueHeight + Self.detailGap + detailHeight
        return Block(height: height) { [self] frame in
            var top = frame.minY
            if iconRow > 0 {
                put([icon: NSRect(x: frame.minX, y: top, width: iconWidth, height: iconSize)])
                top += iconRow
            }
            let room = inline ? width - iconWidth - Self.iconGap : width
            put([
                value: NSRect(x: frame.minX, y: top, width: room, height: valueHeight),
                detail: NSRect(
                    x: frame.minX, y: top + valueHeight + Self.detailGap, width: width,
                    height: detailHeight),
            ])
            if beside {
                let rest = NSRect(
                    x: frame.minX + width + Self.sectionGap, y: frame.minY,
                    width: frame.width - width - Self.sectionGap, height: height)
                put([facts: rest])
            }
            if inline {
                put([
                    icon: NSRect(
                        x: frame.minX + width - iconWidth,
                        y: top + (valueHeight - iconSize) * Self.half,
                        width: iconWidth, height: iconSize)
                ])
            }
        }
    }

    private func placeHeader(in rect: NSRect) {
        let valueHeight = value.intrinsicContentSize.height
        let detailHeight = detail.intrinsicContentSize.height
        let spanHeight = hasSpan ? Self.spanHeight : 0
        let free = rect.height - valueHeight - detailHeight - spanHeight
        let gap = hasSpan ? free * Self.half : free
        let inline = showsIcon(in: rect.width)
        let room = inline ? rect.width - iconWidth - Self.iconGap : rect.width
        put([
            value: NSRect(x: rect.minX, y: rect.minY, width: room, height: valueHeight),
            detail: NSRect(
                x: rect.minX, y: rect.minY + valueHeight + gap, width: rect.width,
                height: detailHeight),
        ])
        if inline {
            put([
                icon: NSRect(
                    x: rect.maxX - iconWidth, y: rect.minY + (valueHeight - iconSize) * Self.half,
                    width: iconWidth, height: iconSize)
            ])
        }
        if hasSpan {
            put([
                span: NSRect(
                    x: rect.minX, y: rect.maxY - spanHeight, width: rect.width, height: spanHeight)
            ])
        }
    }
}
