import AppKit

enum LyricsGeometry {
    static let islandGap: CGFloat = 8
    static let cornerInset: CGFloat = 14
    static let dropGap: CGFloat = 8
    static let desktopInset: (width: CGFloat, height: CGFloat) = (26, 22)
    private static let half: CGFloat = 0.5

    static func frame(for place: LyricsPlace, size: NSSize, in visible: NSRect) -> NSRect {
        switch place {
        case .island: island(size, in: visible)
        case .corner(let corner): self.corner(corner, size: size, in: visible)
        case .menuBar(let anchor): drop(size, below: anchor, in: visible)
        case .desktop: desktop(height: size.height, in: visible)
        }
    }

    static func island(_ size: NSSize, in visible: NSRect) -> NSRect {
        NSRect(
            x: (visible.midX - size.width * half).rounded(),
            y: visible.maxY - islandGap - size.height, width: size.width, height: size.height)
    }

    static func corner(_ corner: LyricsCorner, size: NSSize, in visible: NSRect) -> NSRect {
        NSRect(
            x: corner.isLeading
                ? visible.minX + cornerInset : visible.maxX - cornerInset - size.width,
            y: corner.isTop ? visible.maxY - cornerInset - size.height : visible.minY + cornerInset,
            width: size.width, height: size.height)
    }

    static func drop(_ size: NSSize, below anchor: NSRect, in visible: NSRect) -> NSRect {
        let centred = (anchor.midX - size.width * half).rounded()
        let left = max(visible.minX + dropGap, min(centred, visible.maxX - dropGap - size.width))
        return NSRect(
            x: left, y: min(anchor.minY, visible.maxY) - dropGap - size.height,
            width: size.width, height: size.height)
    }

    static func desktop(height: CGFloat, in visible: NSRect) -> NSRect {
        NSRect(
            x: visible.minX + desktopInset.width, y: visible.minY + desktopInset.height,
            width: max(visible.width - desktopInset.width - desktopInset.width, 0), height: height)
    }

    static func nearest(to point: NSPoint, in visible: NSRect) -> LyricsCorner {
        LyricsCorner(top: point.y >= visible.midY, leading: point.x < visible.midX)
    }

    static func screen(at point: NSPoint, in frames: [NSRect]) -> Int? {
        frames.firstIndex { $0.contains(point) }
            ?? frames.indices.min { first, second in
                distance(from: point, to: frames[first]) < distance(from: point, to: frames[second])
            }
    }

    static func slots(
        size: NSSize, in visible: NSRect, except taken: LyricsCorner?
    ) -> [LyricsCorner: NSRect] {
        var slots: [LyricsCorner: NSRect] = [:]
        for corner in LyricsCorner.allCases where corner != taken {
            slots[corner] = self.corner(corner, size: size, in: visible)
        }
        return slots
    }

    private static func distance(from point: NSPoint, to rect: NSRect) -> CGFloat {
        let across = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let down = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return hypot(across, down)
    }
}
