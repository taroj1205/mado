import AppCore
import AppKit
import IOKit.pwr_mgt

@MainActor
enum SystemCommands {
    enum Failure: Error {
        case accessibilityDenied
        case scriptFailed
        case sleepFailed(IOReturn)
    }

    static let all = [
        Command(
            id: "system.lock", name: "Lock Screen", icon: "lock",
            actions: [CommandAction(id: "lock", title: "Lock Screen", perform: lock)]),
        Command(
            id: "system.sleep", name: "Sleep", icon: "moon.zzz",
            actions: [CommandAction(id: "sleep", title: "Sleep", perform: sleep)]),
        Command(
            id: "system.restart", name: "Restart", icon: "arrow.clockwise",
            actions: [CommandAction(id: "restart", title: "Restart…", perform: restart)],
            keywords: ["reboot"]),
        Command(
            id: "system.empty-trash", name: "Empty Trash", icon: "trash",
            actions: [CommandAction(id: "empty", title: "Empty Trash…", perform: emptyTrash)],
            keywords: ["bin"]),
        Command(
            id: "system.dark-mode", name: "Toggle Dark Mode", icon: "circle.lefthalf.filled",
            actions: [CommandAction(id: "toggle", title: "Toggle", perform: toggleDarkMode)],
            keywords: ["appearance", "light mode", "theme"]),
    ]

    private static func lock() throws {
        guard AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        else { throw Failure.accessibilityDenied }
        try runScript(
            """
            tell application "System Events" to keystroke "q" using {control down, command down}
            """)
    }

    private static func sleep() throws {
        let port = IOPMFindPowerManagement(mach_port_t(MACH_PORT_NULL))
        defer { IOServiceClose(port) }
        let result = IOPMSleepSystem(port)
        guard result == kIOReturnSuccess else { throw Failure.sleepFailed(result) }
    }

    private static func restart() throws {
        try runScript(
            """
            ignoring application responses
                tell application "loginwindow" to «event aevtrrst»
            end ignoring
            """)
    }

    private static func emptyTrash() throws {
        let alert = NSAlert()
        alert.messageText = "Are you sure you want to permanently erase the items in the Trash?"
        alert.informativeText = "You can’t undo this action."
        let empty = alert.addButton(withTitle: "Empty Trash")
        empty.hasDestructiveAction = true
        empty.keyEquivalent = ""
        alert.addButton(withTitle: "Cancel")
        let previous = NSWorkspace.shared.frontmostApplication
        NSApp.activate()
        defer { previous?.activate(from: .current, options: []) }
        guard alert.runModal() == .alertFirstButtonReturn else {
            throw CocoaError(.userCancelled)
        }
        try runScript(
            """
            ignoring application responses
                tell application "Finder" to empty trash
            end ignoring
            """)
    }

    private static func toggleDarkMode() throws {
        try runScript(
            """
            tell application "System Events" to tell appearance preferences
                set dark mode to not dark mode
            end tell
            """)
    }

    static func runScript(_ source: String) throws {
        guard unsafe NSAppleScript(source: source)?.executeAndReturnError(nil) != nil else {
            throw Failure.scriptFailed
        }
    }
}
