import AppKit

extension WidgetTile: NSDraggingSource {
    enum Resize: Equatable {
        case drag(CGFloat)
        case drop
        case step(Int)
    }

    static let badgeSize: CGFloat = 22
    static let badgeOverhang: CGFloat = 8
    private static let gripSize: CGFloat = 14
    private static let gripInset: CGFloat = 8
    private static let half: CGFloat = 0.5

    func arrangeEditing() {
        for outline in [dash, slot] {
            outline.frame = bounds
            outline.autoresizingMask = [.width, .height]
            addSubview(outline)
        }
        let centre = Self.badgeSize * Self.half - Self.badgeOverhang
        remove.onPress = { [weak self] in self?.onRemove?() }
        for view in [remove, grip, resizer] {
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
            resizer.widthAnchor.constraint(equalToConstant: WidgetResizeHandle.size.width),
            resizer.heightAnchor.constraint(equalToConstant: WidgetResizeHandle.size.height),
            resizer.bottomAnchor.constraint(equalTo: bottomAnchor),
            resizer.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        showEditing()
    }

    func editingActions() -> [NSAccessibilityCustomAction] {
        let widths = [("Make Wider", 1), ("Make Narrower", -1)].map { name, change in
            NSAccessibilityCustomAction(name: name) { [weak self] in
                self?.onResize?(.step(change))
                return true
            }
        }
        return [
            NSAccessibilityCustomAction(name: "Remove") { [weak self] in
                self?.onRemove?()
                return true
            },
            NSAccessibilityCustomAction(name: "Add to Selection") { [weak self] in
                self?.onExtend?()
                return true
            },
        ] + (resizable ? widths : [])
    }

    func showEditing() {
        for view in [dash, remove, grip] {
            view.isHidden = !editing
        }
        showGrip()
        month.isInteractive = onPage != nil && !editing
        setAccessibilityCustomActions(customActions())
    }

    func showGrip() {
        resizer.isHidden = !editing || !selected || !resizable
        unsafe window?.invalidateCursorRects(for: resizer)
    }

    func beginResize(_ event: NSEvent) -> Bool {
        guard resizable, resizer.frame.contains(convert(event.locationInWindow, from: nil)) else {
            return false
        }
        resizeStart = screenX(of: event)
        return true
    }

    func screenX(of event: NSEvent) -> CGFloat {
        (unsafe window?.convertPoint(toScreen: event.locationInWindow) ?? event.locationInWindow).x
    }

    func showLifted() {
        for view in subviews where view !== slot {
            view.alphaValue = lifted ? 0 : 1
        }
        slot.isHidden = !lifted
    }

    func pressWhileEditing(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if remove.frame.contains(point) {
            dragStart = nil
            onRemove?()
        } else if beginResize(event) {
            dragStart = nil
            onPress?()
        } else if event.modifierFlags.contains(.shift) {
            dragStart = nil
            onExtend?()
        } else {
            dragStart = event
            onPress?()
        }
    }

    func beginDrag(with event: NSEvent) {
        let item = NSPasteboardItem()
        item.setString(widgetID, forType: WidgetGrid.dragType)
        let dragging = NSDraggingItem(pasteboardWriter: item)
        let card = DragCard.make(of: self, showing: self, radius: Self.radius)
        dragging.setDraggingFrame(card.frame, contents: card.image)
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
