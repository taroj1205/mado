import AppKit

final class CameraFeedback: NSView {
    private static let flashAlpha: CGFloat = 0.85
    private static let flashSeconds = 0.32
    private static let fadeSeconds = 0.18
    private static let holdSeconds = 2.2
    private static let toastHeight: CGFloat = 30
    private static let toastTop: CGFloat = 14
    private static let toastPadding: CGFloat = 14
    private static let half: CGFloat = 0.5

    var reducesMotion = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    let message = FloatingCapsule.label(weight: .medium, color: .labelColor)
    let flash = NSView()
    private(set) lazy var toast = makeToast()
    private var showing = 0

    override init(frame: NSRect) {
        super.init(frame: frame)
        flash.wantsLayer = true
        flash.layer?.backgroundColor = NSColor.white.cgColor
        flash.alphaValue = 0
        toast.alphaValue = 0
        for view in [flash, toast] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            flash.leadingAnchor.constraint(equalTo: leadingAnchor),
            flash.trailingAnchor.constraint(equalTo: trailingAnchor),
            flash.topAnchor.constraint(equalTo: topAnchor),
            flash.bottomAnchor.constraint(equalTo: bottomAnchor),
            toast.centerXAnchor.constraint(equalTo: centerXAnchor),
            toast.topAnchor.constraint(equalTo: topAnchor, constant: Self.toastTop),
            toast.leadingAnchor.constraint(
                greaterThanOrEqualTo: leadingAnchor, constant: Self.toastTop),
            toast.trailingAnchor.constraint(
                lessThanOrEqualTo: trailingAnchor, constant: -Self.toastTop),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func hitTest(_: NSPoint) -> NSView? {
        nil
    }

    func fire() {
        guard !reducesMotion() else { return }
        flash.alphaValue = Self.flashAlpha
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.flashSeconds
            flash.animator().alphaValue = 0
        }
    }

    func show(_ capture: CameraWindow.Capture) {
        message.stringValue = capture.message
        unsafe NSAccessibility.post(
            element: self, notification: .announcementRequested,
            userInfo: [.announcement: capture.message])
        showing += 1
        let token = showing
        fade(to: 1)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.holdSeconds))
            guard let self, showing == token else { return }
            fade(to: 0)
        }
    }

    private func fade(to alpha: CGFloat) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reducesMotion() ? 0 : Self.fadeSeconds
            toast.animator().alphaValue = alpha
        }
    }

    private func makeToast() -> GlassView {
        FloatingCapsule.make(
            NSStackView(views: [message]), leading: Self.toastPadding,
            trailing: Self.toastPadding, height: Self.toastHeight,
            radius: Self.toastHeight * Self.half)
    }
}

extension CameraWindow.Capture {
    var message: String {
        switch self {
        case .saved: "Saved to Pictures and copied"
        case .failed: "Couldn't take the photo"
        }
    }
}
