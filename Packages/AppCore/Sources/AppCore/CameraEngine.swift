import AVFoundation

final class CameraEngine: @unchecked Sendable {
    private static let preset = AVCaptureSession.Preset.hd1280x720

    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.taroj1205.mado.camera")

    func open(_ id: String) async -> Result<CGSize, CameraSession.Failure> {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: self.configure(id)) }
        }
    }

    func close() {
        queue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.session.inputs.forEach(self.session.removeInput)
        }
    }

    private func configure(_ id: String) -> Result<CGSize, CameraSession.Failure> {
        guard let device = AVCaptureDevice(uniqueID: id) else { return .failure(.noCamera) }
        guard let input = try? AVCaptureDeviceInput(device: device) else {
            return .failure(.unreadable)
        }
        session.beginConfiguration()
        session.inputs.forEach(session.removeInput)
        if session.canSetSessionPreset(Self.preset) {
            session.sessionPreset = Self.preset
        }
        let canAdd = session.canAddInput(input)
        if canAdd {
            session.addInput(input)
        }
        session.commitConfiguration()
        guard canAdd else { return .failure(.unreadable) }
        if !session.isRunning {
            session.startRunning()
        }
        let size = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        return .success(CGSize(width: Int(size.width), height: Int(size.height)))
    }
}
