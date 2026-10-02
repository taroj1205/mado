public import AppCore
public import AppKit

@MainActor
public struct PasteboardWatch {
    static let interval: TimeInterval = 0.5

    private let pasteboard: NSPasteboard
    private var changeCount: Int

    init(pasteboard: NSPasteboard) {
        self.pasteboard = pasteboard
        changeCount = pasteboard.changeCount
    }

    public static func install(
        name: String, context: ModuleContext, pasteboard: NSPasteboard = .general,
        onChange: @escaping @MainActor () -> Void
    ) {
        var watch = Self(pasteboard: pasteboard)
        context.scheduleTimer(name, interval: interval) {
            if watch.poll() {
                onChange()
            }
        }
    }

    mutating func poll() -> Bool {
        let count = pasteboard.changeCount
        guard count != changeCount else { return false }
        changeCount = count
        return true
    }
}
