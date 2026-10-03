public import AppCore
import AppKit

@MainActor
public final class AppInputSwitch {
    private static let settleMilliseconds = 150

    private let current: () -> String?
    private let select: (String) -> Void
    private let settle: Duration
    private var front: String?
    private var lastUsed: [String: String] = [:]
    private(set) var pending: Task<Void, Never>?

    init(
        front: String?, current: @escaping () -> String?, select: @escaping (String) -> Void,
        settle: Duration
    ) {
        self.front = front
        self.current = current
        self.select = select
        self.settle = settle
    }

    public static func install(
        context: ModuleContext, settings: @escaping @MainActor () -> InputSourceSettings
    ) {
        let switcher = Self(
            front: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            current: { InputSource.currentID }, select: InputSource.select,
            settle: .milliseconds(settleMilliseconds))
        context.observe(
            NSWorkspace.didActivateApplicationNotification,
            on: NSWorkspace.shared.notificationCenter,
            reading: { notification in
                let key = NSWorkspace.applicationUserInfoKey
                return (notification.userInfo?[key] as? NSRunningApplication)?.bundleIdentifier
            },
            handler: { app in switcher.activated(app, apps: settings().apps) })
        context.own(.task, "input source switch") { switcher.pending?.cancel() }
    }

    func activated(_ app: String?, apps: [String: AppInput]) {
        pending?.cancel()
        if let front, apps[front] == .lastUsed, let source = current() {
            lastUsed[front] = source
        }
        front = app
        guard let source = app.flatMap({ source(for: $0, in: apps) }) else { return }
        pending = Task { [settle, select] in
            try? await Task.sleep(for: settle)
            guard !Task.isCancelled else { return }
            select(source)
        }
    }

    private func source(for app: String, in apps: [String: AppInput]) -> String? {
        switch apps[app] {
        case .source(let id): id
        case .lastUsed: lastUsed[app]
        case nil: nil
        }
    }
}
