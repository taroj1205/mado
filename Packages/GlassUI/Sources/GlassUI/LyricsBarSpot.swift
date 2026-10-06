public import AppKit

public enum LyricsBarSpot {
    public struct Screen: Equatable, Sendable {
        public var frame: NSRect
        public var visibleFrame: NSRect
        public var notchEdge: CGFloat?

        public init(frame: NSRect, visibleFrame: NSRect, notchEdge: CGFloat? = nil) {
            self.frame = frame
            self.visibleFrame = visibleFrame
            self.notchEdge = notchEdge
        }
    }

    static let height: CGFloat = 22
    static let gap: CGFloat = 16
    static let widths: ClosedRange<CGFloat> = 140...300
    static let typeHeight: CGFloat = 64
    static let typeWidths: ClosedRange<CGFloat> = 160...380
    private static let half: CGFloat = 0.5
    private static let slack: CGFloat = 1

    public static func frame(
        for pin: LyricsPin, around surroundings: LyricsSurroundings, on screen: Screen
    ) -> NSRect? {
        switch pin {
        case .dock: dock(surroundings, on: screen)
        case .menus: menus(surroundings, on: screen)
        case .corner, .desktop, .island, .menuBar: nil
        }
    }

    private static func dock(_ surroundings: LyricsSurroundings, on screen: Screen) -> NSRect? {
        let inset = screen.visibleFrame.minY - screen.frame.minY
        guard let items = surroundings.dock, inset >= height,
            screen.visibleFrame.minX == screen.frame.minX,
            screen.visibleFrame.maxX == screen.frame.maxX,
            items.intersects(screen.frame)
        else { return nil }
        let before = items.minX - screen.frame.minX
        let after = screen.frame.maxX - items.maxX
        let span =
            before > after ? (screen.frame.minX, items.minX) : (items.maxX, screen.frame.maxX)
        let frame = fit(
            from: span.0, to: span.1, centre: items.midY, widths: typeWidths, height: typeHeight)
        return frame.flatMap { screen.frame.contains($0) ? $0 : nil }
    }

    private static func menus(_ surroundings: LyricsSurroundings, on screen: Screen) -> NSRect? {
        let thickness = screen.frame.maxY - screen.visibleFrame.maxY
        guard let end = surroundings.menusEnd, thickness >= height else {
            return nil
        }
        let band = NSRect(
            x: screen.frame.minX, y: screen.visibleFrame.maxY, width: screen.frame.width,
            height: thickness)
        let items = surroundings.statusItems.filter { item in
            item.intersects(band) && item.height <= thickness + slack
        }
        let limits = [screen.frame.maxX, screen.notchEdge].compactMap(\.self) + items.map(\.minX)
        return fit(
            from: screen.frame.minX + end, to: limits.min() ?? screen.frame.maxX,
            centre: band.midY, widths: widths, height: height)
    }

    private static func fit(
        from lower: CGFloat, to upper: CGFloat, centre: CGFloat, widths: ClosedRange<CGFloat>,
        height: CGFloat
    ) -> NSRect? {
        let room = upper - lower - gap - gap
        guard room >= widths.lowerBound else { return nil }
        return NSRect(
            x: lower + gap, y: (centre - height * half).rounded(),
            width: min(room, widths.upperBound),
            height: height)
    }
}
