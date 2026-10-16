import AppKit
import AVFoundation

final class CameraPreview: NSView {
    private let session: AVCaptureSession
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private(set) var isMirrored = true

    override var mouseDownCanMoveWindow: Bool { true }

    init(session: AVCaptureSession) {
        self.session = session
        super.init(frame: .zero)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    override func makeBackingLayer() -> CALayer {
        let made = AVCaptureVideoPreviewLayer(session: session)
        made.videoGravity = .resizeAspectFill
        previewLayer = made
        return made
    }

    func mirror(_ mirrored: Bool) {
        isMirrored = mirrored
        guard let connection = previewLayer?.connection, connection.isVideoMirroringSupported
        else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = mirrored
    }
}
