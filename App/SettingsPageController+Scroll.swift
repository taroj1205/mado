import AppKit

extension SettingsPageController {
    private final class Document: NSView {
        override var isFlipped: Bool { true }
    }

    var scrollOrigin: NSPoint {
        get { stack.enclosingScrollView?.contentView.bounds.origin ?? .zero }
        set {
            guard let scroll = stack.enclosingScrollView else { return }
            scroll.documentView?.layoutSubtreeIfNeeded()
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0
                scroll.contentView.animator().setBoundsOrigin(newValue)
            }
            scroll.reflectScrolledClipView(scroll.contentView)
        }
    }

    static func scrolling(_ stack: NSStackView, insets: NSEdgeInsets) -> NSScrollView {
        stack.translatesAutoresizingMaskIntoConstraints = false
        let document = Document()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.automaticallyAdjustsContentInsets = false
        scroll.documentView = document
        scroll.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            document.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            document.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            stack.topAnchor.constraint(equalTo: document.topAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: insets.left),
            stack.trailingAnchor.constraint(
                equalTo: document.trailingAnchor, constant: -insets.right),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -insets.bottom),
        ])
        return scroll
    }
}
