public import AppKit
import ApplicationServices

@MainActor
@safe
public final class FocusWatcher {
    private static let attempts = 10
    private static let retryMilliseconds = 500
    private static let retryDelay = Duration.milliseconds(retryMilliseconds)

    private let onFocus: @MainActor (CGWindowID) -> Void
    private var observers: [pid_t: AXObserver] = [:]
    private var pending: Set<pid_t> = []
    private var tokens: [any NSObjectProtocol] = []
    private var isStopped = false

    public init(onFocus: @escaping @MainActor (CGWindowID) -> Void) {
        self.onFocus = onFocus
        let center = NSWorkspace.shared.notificationCenter
        let changes: [(Notification.Name, @MainActor (FocusWatcher, pid_t) -> Void)] = [
            (NSWorkspace.didActivateApplicationNotification, { $0.activated($1) }),
            (NSWorkspace.didTerminateApplicationNotification, { $0.forget($1) }),
        ]
        tokens = changes.map { name, change in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let key = NSWorkspace.applicationUserInfoKey
                guard let app = note.userInfo?[key] as? NSRunningApplication else { return }
                let pid = app.processIdentifier
                MainActor.assumeIsolated {
                    guard let self else { return }
                    change(self, pid)
                }
            }
        }
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            watch(app.processIdentifier)
        }
    }

    public func stop() {
        isStopped = true
        for token in tokens {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
        tokens = []
        for pid in observers.keys {
            forget(pid)
        }
    }

    private func watch(_ pid: pid_t) {
        guard pid != getpid(), !isStopped, observers[pid] == nil, !pending.contains(pid) else {
            return
        }
        pending.insert(pid)
        let refcon = Int(bitPattern: unsafe Unmanaged.passUnretained(self).toOpaque())
        Task {
            defer { pending.remove(pid) }
            for _ in 0..<Self.attempts {
                if let observer = await FocusObserver.observe(pid, refcon: refcon) {
                    guard !isStopped else { return }
                    CFRunLoopAddSource(
                        CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
                    observers[pid] = observer
                    if NSWorkspace.shared.frontmostApplication?.processIdentifier == pid {
                        report(pid)
                    }
                    return
                }
                try? await Task.sleep(for: Self.retryDelay)
                guard !isStopped else { return }
            }
        }
    }

    private func activated(_ pid: pid_t) {
        guard pid != getpid() else { return }
        report(pid)
        watch(pid)
    }

    private func forget(_ pid: pid_t) {
        guard let observer = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(
            CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }

    func report(_ pid: pid_t) {
        Task {
            guard let number = await WindowList.focusedWindow(of: pid), !isStopped else { return }
            onFocus(number)
        }
    }

    isolated deinit {
        stop()
    }
}
