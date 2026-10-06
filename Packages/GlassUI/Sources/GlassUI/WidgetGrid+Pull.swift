import AppKit

extension WidgetGrid {
    struct Pull: Equatable {
        let id: String
        let start: Size
        let distance: CGSize
    }

    struct Settle {
        let id: String
        let from: NSRect
    }

    private static let give: CGFloat = 24
    private static let settleTime: TimeInterval = 0.34
    private static let bounceOut: (x: Float, y: Float) = (0.34, 1.25)
    private static let bounceIn: (x: Float, y: Float) = (0.64, 1)
    private static let settleCurve = CAMediaTimingFunction(
        controlPoints: bounceOut.x, bounceOut.y, bounceIn.x, bounceIn.y)
    private static let labelGap: CGFloat = 12
    private static let half: CGFloat = 0.5

    private var inlineTiles: [WidgetTile] {
        tiles.filter { !$0.floating }
    }

    private func extent(of size: Size, step: CGSize) -> CGSize {
        CGSize(
            width: CGFloat(size.columns) * step.width - Self.gap,
            height: CGFloat(size.rows) * step.height - Self.gap)
    }

    private func damped(_ distance: CGFloat) -> CGFloat {
        Self.give * (1 - 1 / (distance / Self.give + 1))
    }

    private func elastic(_ value: CGFloat, within range: ClosedRange<CGFloat>) -> CGFloat {
        let held = min(max(value, range.lowerBound), range.upperBound)
        guard !reducesMotion() else { return held }
        return held + damped(max(value - range.upperBound, 0))
            - damped(max(range.lowerBound - value, 0))
    }

    private func pulledExtent(_ pull: Pull) -> CGSize? {
        guard let window = unsafe window, let widget = supplied.first(where: { $0.id == pull.id })
        else { return nil }
        let step = step(of: pull.id, in: window)
        let range = range(of: widget, on: home(of: pull.id).side)
        let start = extent(of: pull.start, step: step)
        let least = extent(of: range.least, step: step)
        let most = extent(of: range.most, step: step)
        return CGSize(
            width: elastic(start.width + pull.distance.width, within: least.width...most.width),
            height: elastic(
                start.height + pull.distance.height, within: least.height...most.height))
    }

    func following(_ frame: NSRect, of id: String) -> NSRect {
        guard let pull, pull.id == id, let extent = pulledExtent(pull) else { return frame }
        pulledFrame = NSRect(origin: frame.origin, size: extent)
        return pulledFrame ?? frame
    }

    func following(floating frame: NSRect, of id: String) -> NSRect {
        guard let pull, pull.id == id, let extent = pulledExtent(pull) else { return frame }
        return NSRect(
            x: frame.minX, y: frame.maxY - extent.height, width: extent.width,
            height: extent.height)
    }

    func placeGuide(over frames: [NSRect]) {
        let index = pull.flatMap { pull in inlineTiles.firstIndex { $0.widgetID == pull.id } }
        guide.isHidden = index == nil
        sizeLabel.isHidden = index == nil
        guard let index, let widget = inlineTiles[index].widget else { return }
        let frame = frames[index]
        guide.frame = frame
        sizeLabel.show(
            widget.size(in: tileLayout).title, symbol: WidgetRailsView.resizeSymbol,
            tint: .controlAccentColor)
        let size = sizeLabel.fittingSize
        let below = frame.maxY + Self.labelGap
        let top =
            below + size.height <= bounds.height
            ? below : frame.minY - Self.labelGap - size.height
        let across = max(bounds.width - size.width, 0)
        let left = min(max(frame.midX - size.width * Self.half, 0), across)
        sizeLabel.frame = NSRect(x: left, y: top, width: size.width, height: size.height)
    }

    func resizeMark(in window: NSWindow) -> WidgetRailsView.Mark? {
        guard let pull, let index = placed.firstIndex(where: { $0.widget.id == pull.id }) else {
            return nil
        }
        let item = placed[index]
        return WidgetRailsView.Mark(
            spot: item.spot, frame: Self.floatingFrames(of: placed, beside: window.frame)[index],
            caption: item.widget.shownSize(on: item.spot.side).title)
    }

    func springSettled() {
        guard let settle = settling, let window = unsafe window else { return }
        settling = nil
        let moves = window.isVisible && !reducesMotion()
        if let index = placed.firstIndex(where: { $0.widget.id == settle.id }) {
            let frame = Self.floatingFrames(of: placed, beside: window.frame)[index]
            let margin = editing ? -WidgetFloatFrame.margin : 0
            let float = floats[index]
            let target = frame.insetBy(dx: margin, dy: margin)
            if moves {
                float.setFrame(settle.from, display: false)
                animate { float.animator().setFrame(target, display: true) }
            } else {
                float.setFrame(target, display: false)
            }
        } else if let index = inlineTiles.firstIndex(where: { $0.widgetID == settle.id }) {
            let frame = frames(of: panelCells)[index]
            let tile = inlineTiles[index]
            let tilt = tilt(at: index)
            guard moves else {
                place(tile, in: frame, tilt: tilt)
                return
            }
            place(tile, in: settle.from, tilt: 0)
            animate(
                { tile.animator().frame = frame },
                then: { self.place(tile, in: frame, tilt: tilt) })
        }
    }

    private func animate(_ change: () -> Void, then done: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = Self.settleTime
                context.timingFunction = Self.settleCurve
                change()
            }, completionHandler: done)
    }

    func repull() {
        needsLayout = true
        placeFloats()
    }

    func arrangeGuide() {
        sizeLabel.isHidden = true
        addSubview(guide)
        addSubview(sizeLabel)
    }
}
