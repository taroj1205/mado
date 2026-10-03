import AppCore
import AppKit
import Dispatch

extension AppDelegate {
    static func makeTerminateSignal() -> any DispatchSourceSignal {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { MainActor.assumeIsolated { NSApp.terminate(nil) } }
        source.resume()
        return source
    }

    func applicationWillTerminate(_: Notification) {
        modules?.stopAll()
    }
}
