public import AppCore

@MainActor
public protocol CameraScreen: AnyObject {
    var onAction: ((CameraWindow.Action) -> Void)? { get set }
    var onSelect: ((CameraDevice) -> Void)? { get set }
    var onMirror: ((Bool) -> Void)? { get set }
    var onCapture: (() -> Bool)? { get set }

    func setPhase(_ phase: CameraWindow.Phase)
    func setDevices(_ devices: [CameraDevice], current: String?)
    func setMirrored(_ mirrored: Bool)
    func showPhoto(_ capture: CameraWindow.Capture)
}
