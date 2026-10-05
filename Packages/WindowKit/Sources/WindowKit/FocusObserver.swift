import ApplicationServices

enum FocusObserver {
    private static let changed: AXObserverCallback = { _, element, _, refcon in
        var pid: pid_t = 0
        guard let info = unsafe refcon, unsafe AXUIElementGetPid(element, &pid) == .success
        else { return }
        let watcher = unsafe Unmanaged<FocusWatcher>.fromOpaque(info).takeUnretainedValue()
        MainActor.assumeIsolated { watcher.report(pid) }
    }

    @concurrent
    static func observe(_ pid: pid_t, refcon: Int) async -> sending AXObserver? {
        var created: AXObserver?
        let status = unsafe AXObserverCreate(pid, changed, &created)
        guard status == .success, let observer = created else { return nil }
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, FocusedWindow.messagingTimeout)
        let added = unsafe AXObserverAddNotification(
            observer, application, kAXFocusedWindowChangedNotification as CFString,
            UnsafeMutableRawPointer(bitPattern: refcon))
        return added == .success ? observer : nil
    }
}
