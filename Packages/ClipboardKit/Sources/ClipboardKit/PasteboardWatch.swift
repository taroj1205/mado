public import AppCore
public import AppKit

@MainActor
public struct PasteboardWatch {
    static let interval: TimeInterval = 0.5
    static let sourceType = NSPasteboard.PasteboardType("org.nspasteboard.source")

    private let pasteboard: NSPasteboard
    private var changeCount: Int

    init(pasteboard: NSPasteboard) {
        self.pasteboard = pasteboard
        changeCount = pasteboard.changeCount
    }

    public static func install(
        name: String, context: ModuleContext, pasteboard: NSPasteboard = .general,
        onChange: @escaping @MainActor (_ sourceApps: [String]) -> Void
    ) {
        var watch = Self(pasteboard: pasteboard)
        var previous = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        context.scheduleTimer(name, interval: interval) {
            let current = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            if watch.poll() {
                onChange(sourceApps(of: pasteboard, frontmost: current, before: previous))
            }
            previous = current
        }
    }

    static func sourceApps(
        of pasteboard: NSPasteboard, frontmost current: String?, before previous: String?
    ) -> [String] {
        guard let declared = pasteboard.string(forType: sourceType) else {
            return (previous == current ? [current] : [previous, current]).compactMap(\.self)
        }
        return declared.isEmpty ? [] : [declared]
    }

    mutating func poll() -> Bool {
        let count = pasteboard.changeCount
        guard count != changeCount else { return false }
        changeCount = count
        return true
    }
}
