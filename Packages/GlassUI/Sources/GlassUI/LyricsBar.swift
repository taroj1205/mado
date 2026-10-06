public import AppKit

@MainActor
public final class LyricsBar {
    public enum Look: Sendable {
        case pill
        case type
    }

    static let fadeSeconds = 0.25

    let panel = OverlayPanel()
    let glass = GlassView(shape: .capsule)
    let line = LyricsMenuBarLine()
    let type = LyricsDockType()
    private let root = NSView()
    public private(set) var isShown = false

    public var frame: NSRect {
        panel.frame
    }

    public var windowNumber: CGWindowID? {
        CGWindowID(exactly: panel.windowNumber)
    }

    public init() {
        panel.animationBehavior = .none
        glass.contentView = line
        panel.contentView = root
    }

    public func show(
        _ verse: WidgetGrid.Verse, look: Look, in frame: NSRect, hidesInSharing: Bool
    ) {
        panel.sharingType = hidesInSharing ? .none : .readOnly
        if look == .pill {
            attach(glass, replacing: type)
            line.show(verse)
        } else {
            attach(type, replacing: glass)
            type.show(verse)
        }
        if panel.frame != frame {
            panel.setFrame(frame, display: true)
        }
        guard !isShown || !panel.isVisible else { return }
        isShown = true
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeSeconds
            panel.animator().alphaValue = 1
        }
    }

    public func hide(animated: Bool) {
        isShown = false
        guard panel.isVisible else { return }
        guard animated else {
            panel.orderOut(nil)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.fadeSeconds
            panel.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated { [weak self] in
                guard let self, !isShown else { return }
                panel.orderOut(nil)
            }
        }
    }

    private func attach(_ view: NSView, replacing other: NSView) {
        other.removeFromSuperview()
        guard unsafe view.superview == nil else { return }
        view.frame = root.bounds
        view.autoresizingMask = [.width, .height]
        root.addSubview(view)
    }
}
