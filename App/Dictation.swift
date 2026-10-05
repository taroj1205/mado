import AppCore
import AppKit
import ClipboardKit
import GlassUI
import InputKit
import os
import SpeechKit

@MainActor
final class Dictation {
    static let key = ModifierTap.Key.rightOption
    private static let hint = "hold right ⌥ to talk"
    private static let denied = "Microphone not allowed"
    private static let unavailable = "Microphone unavailable"
    private static let openSettings = "Open Settings"
    private static let noModel = "Download a speech model in Settings › Voice"
    private static let notTranscribed = "Couldn’t transcribe"
    private static let notPasted = "Couldn’t paste the text"

    private let logger: Logger
    private let settings: @MainActor () -> DictationSettings
    private let models = SpeechModelStore.standard
    private let permissions = PermissionManager()
    private let microphone = Microphone(sampleRate: Transcriber.sampleRate)
    private let transcriber = Transcriber()
    private let pill = DictationPill()
    private var request: Task<Void, Never>?
    private var work: Task<Void, Never>?
    private var model: SpeechModel?
    private var asksOnRelease = false

    var isActive: Bool {
        microphone.isRunning
    }

    private var screen: NSScreen? {
        LauncherScreen.activeWindow.screen
    }

    init(logger: Logger, settings: @escaping @MainActor () -> DictationSettings) {
        self.logger = logger
        self.settings = settings
        pill.onFix = { [permissions] in permissions.openSettings(for: .microphone) }
    }

    func handle(_ event: PushToTalk.Event) {
        switch event {
        case .started: start()
        case .toggled: askForAccess()
        case .stopped: if isActive { finish() } else { askForAccess() }
        case .cancelled: stop()
        }
    }

    func stop() {
        asksOnRelease = false
        request?.cancel()
        request = nil
        work?.cancel()
        work = nil
        microphone.stop()
        pill.hide()
        unload()
    }

    private func unload() {
        Task { [transcriber] in await transcriber.unload() }
    }

    private func start() {
        stop()
        permissions.refresh()
        switch permissions.status(for: .microphone) {
        case .granted:
            record()

        case .notDetermined:
            asksOnRelease = true

        case .denied, .unsupported:
            pill.show(.failed(Self.denied, fix: Self.openSettings), on: screen)
        }
    }

    private func askForAccess() {
        guard asksOnRelease else { return }
        asksOnRelease = false
        request = Task { [permissions] in await permissions.request(.microphone) }
    }

    private func record() {
        guard let installed = models.model(preferring: settings().model) else {
            pill.show(.failed(Self.noModel, fix: nil), on: screen)
            return
        }
        model = installed
        let file = models.location(of: installed)
        work = Task { [transcriber] in try? await transcriber.load(file) }
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
        unload()
        pill.show(.failed(Self.unavailable, fix: nil), on: nil)
    }

    private func finish() {
        let samples = microphone.stop()
        guard let model else {
            stop()
            return
        }
        pill.show(.transcribing, on: nil)
        let file = models.location(of: model)
        work = Task { [weak self, transcriber] in
            do {
                let text = try await transcriber.transcribe(samples, with: file)
                guard !Task.isCancelled else { return }
                await self?.insert(text)
            } catch {
                guard !Task.isCancelled else { return }
                self?.failToTranscribe(error)
            }
        }
    }

    private func failToTranscribe(_ error: any Error) {
        logger.error("Transcribing failed: \(String(describing: error), privacy: .public)")
        pill.show(.failed(Self.notTranscribed, fix: nil), on: nil)
    }

    private func insert(_ text: String) async {
        guard !text.isEmpty else {
            pill.hide()
            return
        }
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        guard let target = PasteTarget.frontmost() else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([item])
            pill.hide()
            return
        }
        do {
            try await target.paste([item])
            guard !Task.isCancelled else { return }
            pill.hide()
        } catch {
            logger.error("Pasting dictation failed: \(String(describing: error), privacy: .public)")
            guard !Task.isCancelled else { return }
            pill.show(.failed(Self.notPasted, fix: nil), on: nil)
        }
    }
}
