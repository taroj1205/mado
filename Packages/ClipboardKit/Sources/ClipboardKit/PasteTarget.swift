public import AppKit
import Carbon.HIToolbox
import InputKit
import IOKit.hidsystem

@MainActor
public struct PasteTarget {
    public enum Failure: Error {
        case notWritten
        case appQuit
        case notActivated
        case notAllowed
        case noKeyEvents
    }

    private static let activationTimeout: Duration = .seconds(1)
    private static let activationPollMilliseconds = 10

    public let app: NSRunningApplication

    init?(app: NSRunningApplication?) {
        guard let app, app != .current, !app.isTerminated else { return nil }
        self.app = app
    }

    public static func frontmost() -> Self? {
        Self(app: NSWorkspace.shared.frontmostApplication)
    }

    static func write(_ items: [any NSPasteboardWriting], to pasteboard: NSPasteboard) throws {
        pasteboard.clearContents()
        guard pasteboard.writeObjects(items) else { throw Failure.notWritten }
    }

    static func commandV() throws -> [CGEvent] {
        let source = CGEventSource(stateID: .hidSystemState)
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval)
        let key = KeyboardLayout.commandKeyCode(typing: "v") ?? CGKeyCode(kVK_ANSI_V)
        let flags = CGEventFlags(
            rawValue: CGEventFlags.maskCommand.rawValue | UInt64(NX_DEVICELCMDKEYMASK))
        let keyDowns = [true, false]
        let events = keyDowns.compactMap { down in
            let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down)
            event?.flags = flags
            return event
        }
        guard events.count == keyDowns.count else { throw Failure.noKeyEvents }
        return events
    }

    public func paste(_ items: [any NSPasteboardWriting]) async throws {
        try Self.write(items, to: .general)
        guard !app.isTerminated else { throw Failure.appQuit }
        app.activate(from: .current, options: [])
        let deadline = ContinuousClock.now + Self.activationTimeout
        while !app.isActive {
            guard ContinuousClock.now < deadline else { throw Failure.notActivated }
            try await Task.sleep(for: .milliseconds(Self.activationPollMilliseconds))
        }
        guard CGPreflightPostEventAccess() else { throw Failure.notAllowed }
        for event in try Self.commandV() {
            event.post(tap: .cghidEventTap)
        }
    }
}
