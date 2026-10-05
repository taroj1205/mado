import AppCore
import os

extension CommandAction {
    @MainActor
    func run(logging logger: Logger) {
        Task {
            do {
                try await perform()
            } catch {
                logger.error("\(id, privacy: .public) failed: \(error, privacy: .private)")
            }
        }
    }
}
