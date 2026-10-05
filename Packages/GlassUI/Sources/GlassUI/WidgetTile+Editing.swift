import AppKit

extension WidgetTile: NSDraggingSource {
    static let badgeSize: CGFloat = 22
    static let badgeOverhang: CGFloat = 8
    private static let gripSize: CGFloat = 14
    private static let gripInset: CGFloat = 8
    private static let half: CGFloat = 0.5
    private static let slotEdge: CGFloat = 1.5
    private static let slotAlpha: CGFloat = 0.16
    private static let cardEdge: CGFloat = 1.5
    private static let cardAlpha: CGFloat = 0.92
    private static let cardTilt: CGFloat = -2
    private static let halfTurn: CGFloat = 180

    static func makeSlot() -> DashedOutline {
        let slot = DashedOutline(
            colour: .controlAccentColor, width: slotEdge,
            fill: .controlAccentColor.withAlphaComponent(slotAlpha))
        slot.isHidden = true
        return slot
    }

    func arrangeEditing() {
        for outline in [dash, slot] {
            outline.frame = bounds
            outline.autoresizingMask = [.width, .height]
            addSubview(outline)
        }
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

    func showLifted() {
        for view in subviews where view !== slot {
            view.alphaValue = lifted ? 0 : 1
        }
        slot.isHidden = !lifted
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
        let card = card()
        dragging.setDraggingFrame(card.frame, contents: card.image)
        beginDraggingSession(with: [dragging], event: event, source: self)
        onDragStart?()
    }

    private func card() -> (frame: CGRect, image: NSImage?) {
        let angle = Self.cardTilt * .pi / Self.halfTurn
        let turned = bounds.applying(CGAffineTransform(rotationAngle: angle)).size
        let frame = CGRect(
            x: bounds.midX - turned.width * Self.half, y: bounds.midY - turned.height * Self.half,
            width: turned.width, height: turned.height)
        guard let content = snapshot() else { return (frame, nil) }
        let tile = CGRect(origin: .zero, size: bounds.size)
        let path = NSBezierPath(
            roundedRect: tile.insetBy(dx: Self.cardEdge * Self.half, dy: Self.cardEdge * Self.half),
            xRadius: Self.radius, yRadius: Self.radius)
        path.lineWidth = Self.cardEdge
        let fill = NSColor.windowBackgroundColor.withAlphaComponent(Self.cardAlpha)
        let appearance = effectiveAppearance
        let image = NSImage(size: turned, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.translateBy(x: rect.midX, y: rect.midY)
            context.rotate(by: angle)
            context.translateBy(x: -tile.midX, y: -tile.midY)
            appearance.performAsCurrentDrawingAppearance {
                fill.setFill()
                path.fill()
                content.draw(in: tile)
                NSColor.controlAccentColor.setStroke()
                path.stroke()
            }
            return true
        }
        return (frame, image)
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
