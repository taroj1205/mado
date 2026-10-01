#if DEBUG
    import AppCore
    import Foundation
    import os

    @MainActor
    func makeToggleSignal(_ toggle: @escaping @MainActor () -> Void) -> any DispatchSourceSignal {
        signal(SIGUSR1, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        source.setEventHandler { MainActor.assumeIsolated { toggle() } }
        source.resume()
        let ready = Bundle.main.bundleURL.deletingLastPathComponent().appending(path: "Mado.ready")
        do {
            try Data().write(to: ready)
        } catch {
            Log.logger("App").error("Toggle signal marker failed: \(error, privacy: .public)")
        }
        return source
    }
#endif
