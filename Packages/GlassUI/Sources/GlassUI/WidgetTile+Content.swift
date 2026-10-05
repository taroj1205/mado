import AppKit

extension WidgetTile {
    func show(_ widget: WidgetGrid.Widget) {
        widgetID = widget.id
        hasTrack = widget.track != nil
        var readings: [WidgetGrid.Meter] = []
        var symbol: String?
        switch widget.content {
        case let .value(_, _, name, _): symbol = name
        case let .meters(list): readings = list
        case let .track(playing): track.show(playing)
        case .month, .event, .loading, .notice, .permission, .unavailable: break
        }
        wash.tint = widget.track == nil ? nil : track.tint
        let visible = showLines(of: widget.content)
        for row in lines.arrangedSubviews {
            row.isHidden = !visible.contains(row)
        }
        icon.image = symbol.flatMap { name in
            NSImage(systemSymbolName: name, accessibilityDescription: nil)
        }
        showMeters(readings)
        showTrack(widget.track != nil)
        month.isInteractive = onPage != nil && !editing
        setAccessibilityLabel(widget.spoken)
        setAccessibilityCustomActions(customActions())
    }

    func customActions() -> [NSAccessibilityCustomAction] {
        if editing { return editingActions() }
        if !month.isHidden { return month.accessibilityActions() }
        return hasTrack ? [skip("Previous Track", .previous), skip("Next Track", .next)] : []
    }

    func showTrack(_ shows: Bool) {
        track.isHidden = !shows
        if shows {
            NSLayoutConstraint.activate(trackPlacement)
        } else {
            NSLayoutConstraint.deactivate(trackPlacement)
        }
    }

    func skip(_ name: String, _ skip: WidgetGrid.Skip) -> NSAccessibilityCustomAction {
        NSAccessibilityCustomAction(name: name) { [weak self] in
            self?.onSkip?(skip)
            return true
        }
    }
}
