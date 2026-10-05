public import AppCore
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

    public var title: String {
        "Paste to \(app.localizedName ?? "Previous App")"
    }

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
        let key = KeyboardLayout.commandKeyCode(typing: "v") ?? CGKeyCode(kVK_ANSI_V)
        let flags = CGEventFlags(
            rawValue: CGEventFlags.maskCommand.rawValue | UInt64(NX_DEVICELCMDKEYMASK))
        return try Keystrokes.press(key, flags: flags, times: 1)
    }

    public func action(pasting text: String) -> CommandAction {
        CommandAction(id: "paste", title: title) {
            try await insert(text)
        }
    }

    public func insert(_ text: String) async throws {
        let insertion = TextInsertion.standard
        repeat {
            try await insertion.waitForRestore()
            try await activate()
        } while insertion.isRestoring
        guard CGPreflightPostEventAccess() else { throw Failure.notAllowed }
        try await insertion.paste(text)
    }

    public func paste(_ items: [any NSPasteboardWriting]) async throws {
        try Self.write(items, to: .general)
        try await activate()
        guard CGPreflightPostEventAccess() else { throw Failure.notAllowed }
        Keystrokes.post(try Self.commandV())
    }

    public func activate() async throws {
        guard !app.isTerminated else { throw Failure.appQuit }
        app.activate(from: .current, options: [])
        let deadline = ContinuousClock.now + Self.activationTimeout
        while !app.isActive {
            guard ContinuousClock.now < deadline else { throw Failure.notActivated }
            try await Task.sleep(for: .milliseconds(Self.activationPollMilliseconds))
        }
    }
}
