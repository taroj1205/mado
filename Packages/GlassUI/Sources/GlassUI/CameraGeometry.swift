import CoreGraphics

enum CameraGeometry {
    static let defaultWidth: CGFloat = 360
    static let minimumWidth: CGFloat = 220
    static let maximumWidth: CGFloat = 960
    static let widescreen = wide / tall
    static let sameShape: CGFloat = 0.01
    private static let wide: CGFloat = 16
    private static let tall: CGFloat = 9
    private static let margin: CGFloat = 24
    private static let gripHeight: CGFloat = 40

    static func aspect(of size: CGSize) -> CGFloat {
        size.width > 0 && size.height > 0 ? size.width / size.height : widescreen
    }

    static func size(width: CGFloat, aspect: CGFloat) -> CGSize {
        let fitted = min(max(width, minimumWidth), maximumWidth)
        return CGSize(width: fitted, height: (fitted / aspect).rounded())
    }

    static func frame(saved: CGRect?, areas: [CGRect]) -> CGRect {
        let size =
            saved.map { size(width: $0.width, aspect: aspect(of: $0.size)) }
            ?? size(width: defaultWidth, aspect: widescreen)
        if let saved {
            let grip = CGRect(
                x: saved.minX, y: saved.maxY - gripHeight, width: size.width, height: gripHeight)
            if areas.contains(where: { $0.intersects(grip) }) {
                return CGRect(
                    origin: CGPoint(x: saved.minX, y: saved.maxY - size.height), size: size)
            }
        }
        let area = areas.first ?? .zero
        return CGRect(
            origin: CGPoint(x: area.maxX - size.width - margin, y: area.minY + margin), size: size)
    }

    static func resized(_ frame: CGRect, widening delta: CGFloat) -> CGRect {
        anchored(frame, width: frame.width + delta, aspect: aspect(of: frame.size))
    }

    static func refit(_ frame: CGRect, aspect: CGFloat) -> CGRect {
        anchored(frame, width: frame.width, aspect: aspect)
    }

    private static func anchored(_ frame: CGRect, width: CGFloat, aspect: CGFloat) -> CGRect {
        let size = size(width: width, aspect: aspect)
        return CGRect(
            origin: CGPoint(x: frame.minX, y: frame.maxY - size.height), size: size)
    }
}
