public import CoreGraphics

public enum ScreenGeometry {
    public struct Screen: Sendable {
        public let frame: CGRect
        public let visibleFrame: CGRect

        public init(frame: CGRect, visibleFrame: CGRect) {
            self.frame = frame
            self.visibleFrame = visibleFrame
        }
    }

    private static let half: CGFloat = 0.5

    public static func quartzRect(fromAppKit rect: CGRect, primary: CGRect) -> CGRect {
        flipped(rect, primary: primary)
    }

    public static func appKitRect(fromQuartz rect: CGRect, primary: CGRect) -> CGRect {
        flipped(rect, primary: primary)
    }

    private static func flipped(_ rect: CGRect, primary: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: primary.maxY - rect.maxY, width: rect.width, height: rect.height)
    }

    public static func screenIndex(showing quartzBounds: CGRect, in frames: [CGRect]) -> Int? {
        guard let primary = frames.first else { return nil }
        let bounds = appKitRect(fromQuartz: quartzBounds, primary: primary)
        let areas = frames.map { frame in
            let overlap = frame.intersection(bounds)
            return overlap.width * overlap.height
        }
        guard let best = areas.indices.max(by: { areas[$0] < areas[$1] }), areas[best] > 0 else {
            return nil
        }
        return best
    }

    public static func quartzFrame(
        _ quartzFrame: CGRect, movedBy step: Int, across screens: [Screen]
    ) -> CGRect? {
        guard let primary = screens.first?.frame,
            let index = screenIndex(showing: quartzFrame, in: screens.map(\.frame))
        else { return nil }
        let order = screens.indices.sorted { lhs, rhs in
            let (left, right) = (screens[lhs].frame, screens[rhs].frame)
            return left.minX == right.minX ? left.maxY > right.maxY : left.minX < right.minX
        }
        guard let position = order.firstIndex(of: index) else { return nil }
        let target = order[(position + step % order.count + order.count) % order.count]
        guard target != index else { return nil }
        let window = appKitRect(fromQuartz: quartzFrame, primary: primary)
        let moved = scaled(
            window, from: screens[index].visibleFrame, to: screens[target].visibleFrame)
        return quartzRect(fromAppKit: moved, primary: primary)
    }

    private static func scaled(_ rect: CGRect, from source: CGRect, to target: CGRect) -> CGRect {
        let scaleX = target.width / source.width
        let scaleY = target.height / source.height
        return CGRect(
            x: (target.minX + (rect.minX - source.minX) * scaleX).rounded(),
            y: (target.minY + (rect.minY - source.minY) * scaleY).rounded(),
            width: (rect.width * scaleX).rounded(), height: (rect.height * scaleY).rounded())
    }

    public static func centeredFrame(of size: CGSize, in visibleFrame: CGRect) -> CGRect {
        let width = min(size.width, visibleFrame.width)
        let height = min(size.height, visibleFrame.height)
        return CGRect(
            x: visibleFrame.midX - width * half, y: visibleFrame.midY - height * half,
            width: width, height: height)
    }
}
