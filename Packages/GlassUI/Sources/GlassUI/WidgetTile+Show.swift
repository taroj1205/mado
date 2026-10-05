import AppKit

extension WidgetTile {
    func show(_ widget: WidgetGrid.Widget) {
        self.widget = widget
        form = WidgetForm(size: bounds.size)
        widgetID = widget.id
        var readings: [WidgetGrid.Meter] = []
        var symbol: String?
        switch widget.content {
        case let .value(_, _, name, _): symbol = name
        case let .meters(list): readings = list
        case let .track(playing): track.show(playing)
        case let .verse(lyrics): verse.show(lyrics)
        case .month, .event, .loading, .notice, .permission, .unavailable: break
        }
        wash.tint = widget.track != nil ? track.tint : widget.verse != nil ? verse.tint : nil
        let visible = showLines(of: widget.content)
        for row in lines.arrangedSubviews {
            row.isHidden = !visible.contains(row)
        }
        icon.image = symbol.flatMap { name in
            NSImage(systemSymbolName: name, accessibilityDescription: nil)
        }
        showMeters(readings)
        showTrack(widget.track != nil)
        showVerse(widget.verse != nil)
        month.isInteractive = onPage != nil && !editing
        setAccessibilityLabel(widget.spoken)
        setAccessibilityCustomActions(customActions())
        showFace()
        showMore()
    }

    func showTrack(_ shows: Bool) {
        track.isHidden = !shows
        if shows {
            NSLayoutConstraint.activate(trackPlacement)
        } else {
            NSLayoutConstraint.deactivate(trackPlacement)
        }
    }
}
