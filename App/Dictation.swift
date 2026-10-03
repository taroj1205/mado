import AppCore
import AppKit
import GlassUI
import InputKit
import os

@MainActor
final class Dictation {
    private static let failureSeconds = 4
    private static let failureLinger: Duration = .seconds(failureSeconds)

    private weak var context: ModuleContext?
    private let permissions: PermissionManager
    private let recorder = DictationRecorder()
    private let pill = DictationPill()
    private var attempt = 0

    init(context: ModuleContext, permissions: PermissionManager) {
        self.context = context
        self.permissions = permissions
        recorder.onLevel = { [weak self] level, elapsed in
            self?.pill.listen(level: level, elapsed: elapsed)
        }
        pill.onFix = { [weak self] problem in self?.fix(problem) }
    }

    func handle(_ event: PushToTalk.Event) {
        switch event {
        case .start: begin()
        case .stop: end(keepingFailure: true)
        case .cancel: end(keepingFailure: false)
        }
    }

    func switchInput() {
        do {
            try recorder.switchInput()
        } catch {
            fail(error)
        }
    }

    func stop() {
        attempt += 1
        recorder.stop()
        pill.hide()
    }

    private func begin() {
        attempt += 1
        let current = attempt
        guard let screen = LauncherScreen.activeWindow.screen else { return }
        pill.showReady(on: screen)
        context?.run("dictation start") { [weak self, permissions] in
            let status = await permissions.request(.microphone)
            guard let self, current == attempt else { return }
            guard status == .granted else {
                pill.fail(.notAllowed)
                return
            }
            do {
                try recorder.start()
            } catch {
                fail(error)
            }
        }
    }

    private func end(keepingFailure: Bool) {
        attempt += 1
        let current = attempt
        recorder.stop()
        guard keepingFailure, pill.isFailed else {
            pill.hide()
            return
        }
        context?.run("dictation failure") { [weak self] in
            try? await Task.sleep(for: Self.failureLinger)
            guard let self, current == attempt else { return }
            pill.hide()
        }
    }

    private func fail(_ error: any Error) {
        context?.logger.error("Microphone failed: \(error, privacy: .public)")
        recorder.stop()
        pill.fail(.unavailable)
    }

    private func fix(_ problem: DictationPill.Problem) {
        attempt += 1
        switch problem {
        case .notAllowed:
            permissions.openSettings(for: .microphone)

        case .unavailable:
            guard let url = URL(string: SettingsPane.sound.id) else { return }
            NSWorkspace.shared.open(url)
        }
    }
}
