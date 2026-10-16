import AVFoundation

final class CameraEngine: @unchecked Sendable {
    private static let preset = AVCaptureSession.Preset.hd1280x720

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "com.taroj1205.mado.camera")
    private var shots: [Int64: PhotoShot] = [:]

    func open(_ id: String) async -> Result<CGSize, CameraSession.Failure> {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: self.configure(id)) }
        }
    }

    func close() {
        queue.async { self.stop() }
    }

    func capture(mirrored: Bool) async -> Data? {
        await withCheckedContinuation { continuation in
            queue.async {
                guard self.session.isRunning, let connection = self.output.connection(with: .video),
                    self.output.availablePhotoCodecTypes.contains(.jpeg)
                else {
                    continuation.resume(returning: nil)
                    return
                }
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = mirrored
                }
                let settings = AVCapturePhotoSettings()
                let id = settings.uniqueID
                let shot = PhotoShot { data in
                    self.queue.async { self.shots[id] = nil }
                    continuation.resume(returning: data)
                }
                self.shots[id] = shot
                self.output.capturePhoto(with: settings, delegate: shot)
            }
        }
    }

    private func stop() {
        if session.isRunning {
            session.stopRunning()
        }
        session.inputs.forEach(session.removeInput)
    }

    private func configure(_ id: String) -> Result<CGSize, CameraSession.Failure> {
        guard let device = AVCaptureDevice(uniqueID: id) else {
            stop()
            return .failure(.noCamera)
        }
        guard let input = try? AVCaptureDeviceInput(device: device) else {
            stop()
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
        let hasOutput = session.outputs.contains(output) || session.canAddOutput(output)
        if hasOutput, !session.outputs.contains(output) {
            session.addOutput(output)
        }
        session.commitConfiguration()
        guard canAdd, hasOutput else {
            stop()
            return .failure(.unreadable)
        }
        if !session.isRunning {
            session.startRunning()
        }
        guard session.isRunning else {
            stop()
            return .failure(.unreadable)
        }
        let size = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        return .success(CGSize(width: Int(size.width), height: Int(size.height)))
    }
}
