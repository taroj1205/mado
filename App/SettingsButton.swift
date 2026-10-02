import AppCore
import AppKit
import os

final class SettingsButton: NSButton {
    private let logger = Log.logger("Settings")
    private let run: @MainActor () async throws -> Void

    init(_ title: String, run: @escaping @MainActor () async throws -> Void) {
        self.run = run
        super.init(frame: .zero)
        self.title = title
        bezelStyle = .push
        target = self
        action = #selector(pressed)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        nil
    }

    @objc
    private func pressed() {
        isEnabled = false
        Task {
            do {
                try await run()
            } catch {
                logger.error("\(self.title, privacy: .public) failed: \(error, privacy: .public)")
                presentError(error)
            }
            isEnabled = true
        }
    }
}
