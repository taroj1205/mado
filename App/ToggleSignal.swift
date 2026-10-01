#if DEBUG
    import Dispatch

    @MainActor
    func makeToggleSignal(_ toggle: @escaping @MainActor () -> Void) -> any DispatchSourceSignal {
        signal(SIGUSR1, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        source.setEventHandler { MainActor.assumeIsolated { toggle() } }
        source.resume()
        return source
    }
#endif
