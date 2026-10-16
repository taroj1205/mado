import AppCore
import AppKit
import GlassUI

@MainActor
final class CameraMirror {
    static let commandID = "system.camera"
    private static let pollSeconds = 1

    private let modules: () -> ModuleManager?
    let camera = CameraSession()
    private let permissions = PermissionManager()
    private lazy var window = makeWindow()
    private var current: String?
    private var isOpen = false
    private var watching: Task<Void, Never>?
    private var run = 0

    var command: Command {
        Command(
            id: Self.commandID, name: "Camera", icon: "video",
            actions: [
                CommandAction(id: "toggle", title: "Show or Hide Camera") { [weak self] in
                    self?.toggle()
                }
            ],
            keywords: ["webcam", "mirror", "selfie", "facetime", "video"])
    }

    var settings: CameraSettings {
        CameraSettings.load(from: modules())
    }

    init(modules: @escaping () -> ModuleManager?) {
        self.modules = modules
        camera.onDevicesChanged = { [weak self] in self?.devicesChanged() }
        camera.onFailed = { [weak self] in self?.failed() }
    }

    func toggle() {
        if isOpen {
            close()
        } else {
            show()
        }
    }

    func show() {
        guard !isOpen else { return }
        isOpen = true
        let saved = settings
        camera.retain()
        window.show(saved: saved.frame, mirrored: saved.mirrored)
        begin(preferring: saved.deviceID)
    }

    private func makeWindow() -> CameraWindow {
        let made = CameraWindow(session: camera.captureSession)
        made.onClose = { [weak self] in self?.close() }
        made.onMirror = { [weak self] mirrored in self?.update { $0.mirrored = mirrored } }
        made.onFrame = { [weak self] frame in self?.update { $0.frame = frame } }
        made.onSelect = { [weak self] device in
            self?.update { $0.deviceID = device.id }
            self?.begin(preferring: device.id)
        }
        made.onAction = { [weak self] action in
            switch action {
            case .openSettings: self?.permissions.openSettings(for: .camera)

            case .retry:
                self?.begin(preferring: self?.settings.deviceID)
            }
        }
        return made
    }

    private func close() {
        guard isOpen else { return }
        isOpen = false
        run += 1
        watching?.cancel()
        watching = nil
        current = nil
        window.hide()
        camera.release()
    }

    private func begin(preferring saved: String?) {
        run += 1
        let mine = run
        watching?.cancel()
        watching = nil
        Task { [weak self] in await self?.connect(mine, preferring: saved) }
    }

    private func connect(_ mine: Int, preferring saved: String?) async {
        window.setPhase(.starting)
        permissions.refresh()
        var status = permissions.status(for: .camera)
        if status == .notDetermined {
            status = await permissions.request(.camera)
        }
        guard run == mine else { return }
        guard status == .granted else {
            window.setPhase(.denied)
            waitForPermission(mine)
            return
        }
        let result = await camera.start(preferring: saved)
        guard run == mine else { return }
        switch result {
        case .success(let opened):
            current = opened.device.id
            window.fit(to: opened.size)
            window.setDevices(CameraSession.devices(), current: opened.device.id)
            window.setPhase(.live)

        case .failure(.noCamera):
            current = nil
            window.setPhase(.noCamera)

        case .failure(.unreadable):
            current = nil
            window.setPhase(.failed)
        }
    }

    private func waitForPermission(_ mine: Int) {
        watching = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.pollSeconds))
                guard let self, run == mine else { return }
                permissions.refresh()
                if permissions.status(for: .camera) == .granted {
                    begin(preferring: settings.deviceID)
                    return
                }
            }
        }
    }

    func quit() {
        if isOpen { close() }
    }

    private func failed() {
        guard window.isShown else { return }
        current = nil
        window.setPhase(.failed)
    }

    private func devicesChanged() {
        guard window.isShown else { return }
        let devices = CameraSession.devices()
        if let current, devices.contains(where: { $0.id == current }) {
            window.setDevices(devices, current: current)
        } else {
            begin(preferring: settings.deviceID)
        }
    }

    private func update(_ change: (inout CameraSettings) -> Void) {
        var updated = settings
        change(&updated)
        updated.save(to: modules())
    }
}
