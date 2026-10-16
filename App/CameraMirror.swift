import AppCore
import AppKit
import GlassUI
import os

@MainActor
final class CameraMirror {
    static let commandID = "system.camera"
    static let inlineActionID = "inline"
    static let title = "Camera"
    static let symbol = "video"
    static let placeholder = "Press ↵ to take a photo"
    private static let pollSeconds = 1
    private static let logger = Log.logger("CameraMirror")

    private(set) var isRequestingAccess = false
    var onOpen: (() -> Void)?
    var onPopOut: (() -> Void)?
    private let modules: () -> ModuleManager?
    private let camera = CameraSession()
    private let permissions = PermissionManager()
    private let inline: CameraPane
    private lazy var window = makeWindow()
    private var phase = CameraWindow.Phase.starting
    private var devices: [CameraDevice] = []
    private var current: String?
    private var videoSize: CGSize?
    private var windowOpen = false
    private var inlineOpen = false
    private var capturing = false
    private var watching: Task<Void, Never>?
    private var run = 0

    var command: Command {
        Command(
            id: Self.commandID, name: Self.title, icon: Self.symbol,
            actions: [
                CommandAction(id: Self.inlineActionID, title: "Open Camera") { [weak self] in
                    self?.onOpen?()
                },
                CommandAction(id: "toggle", title: "Show or Hide Camera Window") { [weak self] in
                    self?.toggle()
                },
            ],
            keywords: ["webcam", "mirror", "selfie", "facetime", "video", "photo", "picture"])
    }

    private var screens: [any CameraScreen] {
        var open: [any CameraScreen] = []
        if inlineOpen { open.append(inline) }
        if windowOpen { open.append(window) }
        return open
    }

    init(inline: CameraPane, modules: @escaping () -> ModuleManager?) {
        self.inline = inline
        self.modules = modules
        inline.use(camera.captureSession)
        wire(inline)
        inline.onPopOut = { [weak self] in
            self?.openWindow()
            self?.onPopOut?()
        }
        camera.onDevicesChanged = { [weak self] in self?.devicesChanged() }
        camera.onFailed = { [weak self] in self?.failed() }
    }

    func toggle() {
        if windowOpen {
            closeWindow()
        } else {
            openWindow()
        }
    }

    func openInline() {
        guard !inlineOpen else { return }
        inlineOpen = true
        join(inline)
    }

    func closeInline() {
        guard inlineOpen else { return }
        inlineOpen = false
        releaseIfIdle()
    }

    func quit() {
        closeInline()
        closeWindow()
    }

    private func openWindow() {
        guard !windowOpen else { return }
        windowOpen = true
        let settings = CameraSettings.load(from: modules())
        window.show(saved: settings.frame, mirrored: settings.mirrored)
        join(window)
        if phase == .live, let videoSize { window.fit(to: videoSize) }
    }

    private func closeWindow() {
        guard windowOpen else { return }
        windowOpen = false
        window.hide()
        releaseIfIdle()
    }

    private func makeWindow() -> CameraWindow {
        let made = CameraWindow(session: camera.captureSession)
        wire(made)
        made.onClose = { [weak self] in self?.closeWindow() }
        made.onFrame = { [weak self] frame in self?.update { $0.frame = frame } }
        return made
    }

    private func wire(_ screen: any CameraScreen) {
        screen.onMirror = { [weak self] mirrored in
            self?.update { $0.mirrored = mirrored }
            self?.screens.forEach { $0.setMirrored(mirrored) }
        }
        screen.onSelect = { [weak self] device in
            self?.update { $0.deviceID = device.id }
            self?.begin(preferring: device.id)
        }
        screen.onAction = { [weak self] action in
            switch action {
            case .openSettings: self?.permissions.openSettings(for: .camera)

            case .retry:
                self?.begin(preferring: CameraSettings.load(from: self?.modules()).deviceID)
            }
        }
        screen.onCapture = { [weak self] in self?.capture() ?? false }
    }

    private func join(_ screen: any CameraScreen) {
        let settings = CameraSettings.load(from: modules())
        screen.setMirrored(settings.mirrored)
        if screens.count > 1 {
            screen.setDevices(devices, current: current)
            screen.setPhase(phase)
        } else {
            begin(preferring: settings.deviceID)
        }
    }

    private func releaseIfIdle() {
        guard !windowOpen, !inlineOpen else { return }
        capturing = false
        run += 1
        watching?.cancel()
        watching = nil
        current = nil
        videoSize = nil
        camera.stop()
    }

    private func show(_ next: CameraWindow.Phase) {
        phase = next
        screens.forEach { $0.setPhase(next) }
    }

    private func begin(preferring saved: String?) {
        run += 1
        let mine = run
        watching?.cancel()
        watching = nil
        Task { [weak self] in await self?.connect(mine, preferring: saved) }
    }

    private func connect(_ mine: Int, preferring saved: String?) async {
        show(.starting)
        permissions.refresh()
        var status = permissions.status(for: .camera)
        if status == .notDetermined {
            isRequestingAccess = true
            status = await permissions.request(.camera)
            isRequestingAccess = false
        }
        guard run == mine else { return }
        guard status == .granted else {
            show(.denied)
            waitForPermission(mine)
            return
        }
        let result = await camera.start(preferring: saved)
        guard run == mine else { return }
        switch result {
        case .success(let opened):
            current = opened.device.id
            videoSize = opened.size
            devices = CameraSession.devices()
            if windowOpen { window.fit(to: opened.size) }
            screens.forEach { $0.setDevices(devices, current: opened.device.id) }
            show(.live)

        case .failure(.noCamera):
            current = nil
            videoSize = nil
            show(.noCamera)

        case .failure(.unreadable):
            current = nil
            videoSize = nil
            show(.failed)
        }
    }

    private func waitForPermission(_ mine: Int) {
        watching = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.pollSeconds))
                guard let self, run == mine else { return }
                permissions.refresh()
                if permissions.status(for: .camera) == .granted {
                    begin(preferring: CameraSettings.load(from: modules()).deviceID)
                    return
                }
            }
        }
    }

    private func capture() -> Bool {
        guard phase == .live, !capturing else { return false }
        capturing = true
        Task { [weak self] in
            guard let self else { return }
            let mirrored = CameraSettings.load(from: modules()).mirrored
            let outcome = await takePhoto(mirrored: mirrored)
            capturing = false
            screens.forEach { $0.showPhoto(outcome) }
        }
        return true
    }

    private func takePhoto(mirrored: Bool) async -> CameraWindow.Capture {
        guard let data = await camera.takePhoto(mirrored: mirrored) else { return .failed }
        do {
            _ = try CameraPhoto.save(data, in: CameraPhoto.folder)
        } catch {
            Self.logger.error("Saving the photo failed: \(error, privacy: .public)")
            return .failed
        }
        guard CameraPhoto.copy(data, to: .general) else {
            Self.logger.error("Copying the photo failed")
            return .savedNotCopied
        }
        return .saved
    }

    private func failed() {
        guard !screens.isEmpty else { return }
        current = nil
        videoSize = nil
        show(.failed)
    }

    private func devicesChanged() {
        guard !screens.isEmpty else { return }
        let found = CameraSession.devices()
        if let current, found.contains(where: { $0.id == current }) {
            devices = found
            screens.forEach { $0.setDevices(found, current: current) }
        } else {
            begin(preferring: CameraSettings.load(from: modules()).deviceID)
        }
    }

    private func update(_ change: (inout CameraSettings) -> Void) {
        var settings = CameraSettings.load(from: modules())
        change(&settings)
        settings.save(to: modules())
    }
}
