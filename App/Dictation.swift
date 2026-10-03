import AppCore
import AppKit
import GlassUI
import InputKit
import os

@MainActor
final class Dictation {
    static let key = ModifierTap.Key.rightOption
    private static let hint = "hold right ⌥ to talk"
    private static let denied = "Microphone not allowed"
    private static let unavailable = "Microphone unavailable"
    private static let openSettings = "Open Settings"

    private let logger: Logger
    private let permissions = PermissionManager()
    private let microphone = Microphone()
    private let pill = DictationPill()
    private var request: Task<Void, Never>?

    var isActive: Bool {
        microphone.isRunning
    }

    private var screen: NSScreen? {
        LauncherScreen.activeWindow.screen
    }

    init(logger: Logger) {
        self.logger = logger
        pill.onFix = { [permissions] in permissions.openSettings(for: .microphone) }
    }

    func handle(_ event: PushToTalk.Event) {
        switch event {
        case .started: start()
        case .stopped, .cancelled: if isActive { stop() }
        }
    }

    func stop() {
        request?.cancel()
        request = nil
        microphone.stop()
        pill.hide()
    }

    private func start() {
        stop()
        permissions.refresh()
        switch permissions.status(for: .microphone) {
        case .granted:
            record()

        case .notDetermined:
            request = Task { [permissions] in await permissions.request(.microphone) }

        case .denied, .unsupported:
            pill.show(.failed(Self.denied, fix: Self.openSettings), on: screen)
        }
    }

    private func record() {
        pill.show(.ready(hint: Self.hint), on: screen)
        do {
            try microphone.start { [weak self] level in
                self?.hear(level)
            } onFailure: { [weak self] error in
                self?.fail(error)
            }
        } catch {
            fail(error)
        }
    }

    private func hear(_ level: Double) {
        if case .ready = pill.state {
            pill.show(.listening(since: .now), on: nil)
        }
        pill.hear(level)
    }

    private func fail(_ error: any Error) {
        logger.error("Recording failed: \(String(describing: error), privacy: .public)")
        microphone.stop()
        pill.show(.failed(Self.unavailable, fix: nil), on: nil)
    }
}
