public import AppCore
import AppKit

@MainActor
public final class AppInputSwitch {
    private let current: () -> String?
    private let select: (String) -> Void
    private var front: String?
    private var lastUsed: [String: String] = [:]

    init(
        front: String?, current: @escaping () -> String?, select: @escaping (String) -> Void
    ) {
        self.front = front
        self.current = current
        self.select = select
    }

    public static func install(
        context: ModuleContext, settings: @escaping @MainActor () -> InputSourceSettings
    ) {
        let switcher = Self(
            front: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            current: { InputSource.currentID }, select: InputSource.select)
        context.observe(
            NSWorkspace.didActivateApplicationNotification,
            on: NSWorkspace.shared.notificationCenter,
            reading: { notification in
                let key = NSWorkspace.applicationUserInfoKey
                return (notification.userInfo?[key] as? NSRunningApplication)?.bundleIdentifier
            },
            handler: { app in switcher.activated(app, apps: settings().apps) })
    }

    func activated(_ app: String?, apps: [String: AppInput]) {
        if let front, apps[front] == .lastUsed, let source = current() {
            lastUsed[front] = source
        }
        front = app
        guard let app else { return }
        switch apps[app] {
        case .source(let id): select(id)
        case .lastUsed: lastUsed[app].map(select)
        case nil: break
        }
    }
}
