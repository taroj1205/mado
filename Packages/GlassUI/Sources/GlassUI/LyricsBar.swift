public import AppKit

@MainActor
public final class LyricsBar {
    static let fadeSeconds = 0.25

    let panel = GlassPanel(kind: .hud, contentRect: .zero, shape: .capsule)
    let line = LyricsMenuBarLine()
    public private(set) var isShown = false

    public var frame: NSRect {
        panel.frame
    }

    public var windowNumber: CGWindowID? {
        CGWindowID(exactly: panel.windowNumber)
    }

    public init() {
        panel.animationBehavior = .none
        panel.hasShadow = false
        panel.glass.contentView = line
    }

    public func show(_ verse: WidgetGrid.Verse, in frame: NSRect, hidesInSharing: Bool) {
        panel.sharingType = hidesInSharing ? .none : .readOnly
        line.show(verse)
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
}
