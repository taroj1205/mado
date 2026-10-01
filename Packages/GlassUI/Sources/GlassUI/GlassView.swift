public import AppKit

public final class GlassView: NSView {
    public enum Shape: Sendable {
        case rounded(CGFloat)
        case capsule

        private static let half: CGFloat = 0.5

        func radius(in size: NSSize) -> CGFloat {
            let limit = min(size.width, size.height) * Self.half
            return switch self {
            case .rounded(let radius): max(0, min(radius, limit))
            case .capsule: limit
            }
        }
    }

    public let shape: Shape

    public var contentView: NSView? {
        didSet {
            guard oldValue !== contentView else { return }
            if #available(macOS 26, *), let glass = effect as? NSGlassEffectView {
                glass.contentView = contentView
                return
            }
            oldValue?.removeFromSuperview()
            guard let contentView else { return }
            contentView.frame = effect.bounds
            contentView.autoresizingMask = [.width, .height]
            effect.addSubview(contentView)
        }
    }

    let effect: NSView
    private var radius: CGFloat?

    public init(shape: Shape) {
        self.shape = shape
        if #available(macOS 26, *) {
            let glass = NSGlassEffectView()
            glass.style = .clear
            effect = glass
        } else {
            let view = NSVisualEffectView()
            view.material = .popover
            view.blendingMode = .behindWindow
            view.state = .active
            effect = view
        }
        super.init(frame: .zero)
        effect.autoresizingMask = [.width, .height]
        addSubview(effect)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    static func mask(radius: CGFloat) -> NSImage {
        let edge = radius + 1 + radius
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    override public func layout() {
        super.layout()
        let next = shape.radius(in: bounds.size)
        guard next != radius else { return }
        radius = next
        if #available(macOS 26, *), let glass = effect as? NSGlassEffectView {
            glass.cornerRadius = next
        } else if let view = effect as? NSVisualEffectView {
            view.maskImage = Self.mask(radius: next)
        }
        unsafe window?.invalidateShadow()
    }
}
