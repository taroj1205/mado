public import CoreGraphics

public enum ScreenGeometry {
    private static let half: CGFloat = 0.5

    public static func screenIndex(showing quartzBounds: CGRect, in frames: [CGRect]) -> Int? {
        guard let primary = frames.first else { return nil }
        let bounds = CGRect(
            x: quartzBounds.minX, y: primary.maxY - quartzBounds.maxY,
            width: quartzBounds.width, height: quartzBounds.height)
        let areas = frames.map { frame in
            let overlap = frame.intersection(bounds)
            return overlap.width * overlap.height
        }
        guard let best = areas.indices.max(by: { areas[$0] < areas[$1] }), areas[best] > 0 else {
            return nil
        }
        return best
    }

    public static func centeredFrame(of size: CGSize, in visibleFrame: CGRect) -> CGRect {
        let width = min(size.width, visibleFrame.width)
        let height = min(size.height, visibleFrame.height)
        return CGRect(
            x: visibleFrame.midX - width * half, y: visibleFrame.midY - height * half,
            width: width, height: height)
    }
}
