import AppKit
import AVFoundation

final class WidgetCamera: NSView {
    private static let bezel: CGFloat = 4
    private var preview: CameraPreview?
    private var session: AVCaptureSession?

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = WidgetTile.radius - Self.bezel
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        isHidden = true
        setAccessibilityElement(false)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func viewDidMoveToSuperview() {
        guard let parent = unsafe superview else { return }
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: parent.leadingAnchor, constant: Self.bezel),
            trailingAnchor.constraint(equalTo: parent.trailingAnchor, constant: -Self.bezel),
            topAnchor.constraint(equalTo: parent.topAnchor, constant: Self.bezel),
            bottomAnchor.constraint(equalTo: parent.bottomAnchor, constant: -Self.bezel),
        ])
    }

    func show(_ live: WidgetGrid.Live) {
        if session !== live.session {
            preview?.removeFromSuperview()
            let made = CameraPreview(session: live.session)
            made.frame = bounds
            made.autoresizingMask = [.width, .height]
            addSubview(made)
            preview = made
            session = live.session
        }
        preview?.mirror(live.mirrored)
    }
}
