import AVFoundation

final class PhotoShot: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let finish: @Sendable (Data?) -> Void
    private var data: Data?

    init(finish: @escaping @Sendable (Data?) -> Void) {
        self.finish = finish
    }

    func photoOutput(
        _: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?
    ) {
        data = error == nil ? photo.fileDataRepresentation() : nil
    }

    func photoOutput(
        _: AVCapturePhotoOutput,
        didFinishCaptureFor _: AVCaptureResolvedPhotoSettings, error _: (any Error)?
    ) {
        finish(data)
    }
}
