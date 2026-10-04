import AppKit

extension WidgetTile: NSDraggingSource {
    static let badgeSize: CGFloat = 22
    static let badgeOverhang: CGFloat = 8
    private static let gripSize: CGFloat = 14
    private static let gripInset: CGFloat = 8
    private static let half: CGFloat = 0.5

    func arrangeEditing() {
        dash.frame = bounds
        dash.autoresizingMask = [.width, .height]
        addSubview(dash)
        let centre = Self.badgeSize * Self.half - Self.badgeOverhang
        remove.onPress = { [weak self] in self?.onRemove?() }
        for view in [remove, grip] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            remove.widthAnchor.constraint(equalToConstant: Self.badgeSize),
            remove.heightAnchor.constraint(equalToConstant: Self.badgeSize),
            remove.centerXAnchor.constraint(equalTo: leadingAnchor, constant: centre),
            remove.centerYAnchor.constraint(equalTo: topAnchor, constant: centre),
            grip.widthAnchor.constraint(equalToConstant: Self.gripSize),
            grip.heightAnchor.constraint(equalToConstant: Self.gripSize),
            grip.topAnchor.constraint(equalTo: topAnchor, constant: Self.gripInset),
            grip.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.gripInset),
        ])
        showEditing()
    }

    func showEditing() {
        for view in [dash, remove, grip] {
            view.isHidden = !editing
        }
    }

    func pressWhileEditing(_ event: NSEvent) {
        if remove.frame.contains(convert(event.locationInWindow, from: nil)) {
            dragStart = nil
            onRemove?()
        } else {
            dragStart = event
            onPress?()
        }
    }

    func beginDrag(with event: NSEvent) {
        let item = NSPasteboardItem()
        item.setString(widgetID, forType: WidgetGrid.dragType)
        let dragging = NSDraggingItem(pasteboardWriter: item)
        dragging.setDraggingFrame(bounds, contents: snapshot())
        beginDraggingSession(with: [dragging], event: event, source: self)
        onDragStart?()
    }

    func draggingSession(
        _: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        context == .withinApplication ? .move : []
    }

    func draggingSession(_: NSDraggingSession, endedAt _: NSPoint, operation: NSDragOperation) {
        if operation.isEmpty {
            onDragEnd?()
        }
    }
}
