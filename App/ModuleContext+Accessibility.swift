import AppCore
import os

extension ModuleContext {
    private static let accessibilityRetry: Duration = .seconds(1)

    func installWhenTrusted(_ name: String, install: @escaping @MainActor () -> Bool) {
        guard !install() else { return }
        logger.notice("Waiting for Accessibility: \(name, privacy: .public)")
        run("wait for Accessibility") {
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.accessibilityRetry)
                if !Task.isCancelled, install() { return }
            }
        }
    }
}
