public import AVFoundation

extension WidgetGrid {
    public struct Live: @unchecked Sendable, Equatable {
        public let session: AVCaptureSession
        public let mirrored: Bool

        public init(session: AVCaptureSession, mirrored: Bool) {
            self.session = session
            self.mirrored = mirrored
        }

        public static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.session === rhs.session && lhs.mirrored == rhs.mirrored
        }
    }
}
