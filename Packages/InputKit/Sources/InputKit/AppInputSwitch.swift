public import AppCore
import AppKit

@MainActor
public final class AppInputSwitch {
    @MainActor
    public final class Memory {
        var lastUsed: [String: String]

        public init() {
            lastUsed = [:]
        }
    }

    private static let settleMilliseconds = 150

    private let current: () -> String?
    private let select: (String) -> Void
    private let settle: Duration
    private let memory: Memory
    private var front: String?
    private(set) var pending: Task<Void, Never>?

    init(
        front: String?, current: @escaping () -> String?, select: @escaping (String) -> Void,
        settle: Duration, memory: Memory
    ) {
        self.front = front
        self.current = current
        self.select = select
        self.settle = settle
        self.memory = memory
    }

    public static func install(
        context: ModuleContext, settings: @escaping @MainActor () -> InputSourceSettings,
        memory: Memory
    ) {
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let switcher = Self(
            front: nil, current: { InputSource.currentID }, select: InputSource.select,
            settle: .milliseconds(settleMilliseconds), memory: memory)
        context.observe(
            NSWorkspace.didActivateApplicationNotification,
            on: NSWorkspace.shared.notificationCenter,
            reading: { notification in
                let key = NSWorkspace.applicationUserInfoKey
                return (notification.userInfo?[key] as? NSRunningApplication)?.bundleIdentifier
            },
            handler: { app in switcher.activated(app, apps: settings().apps) })
        context.own(.task, "input source switch") {
            switcher.activated(nil, apps: settings().apps)
        }
        switcher.activated(frontmost, apps: settings().apps)
    }

    func activated(_ app: String?, apps: [String: AppInput]) {
        let settled = pending == nil
        pending?.cancel()
        pending = nil
        if settled, let front, apps[front] == .lastUsed, let source = current() {
            memory.lastUsed[front] = source
        }
        front = app
        guard let source = app.flatMap({ source(for: $0, in: apps) }) else { return }
        pending = Task { [weak self, settle, select] in
            try? await Task.sleep(for: settle)
            guard !Task.isCancelled else { return }
            select(source)
            self?.pending = nil
        }
    }

    private func source(for app: String, in apps: [String: AppInput]) -> String? {
        switch apps[app] {
        case .source(let id): id
        case .lastUsed: memory.lastUsed[app]
        case nil: nil
        }
    }
}
