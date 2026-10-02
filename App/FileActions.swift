import AppCore
import AppKit
import SearchKit

@MainActor
enum FileActions {
    static let openWithTitle = "Open With…"
    static let showInfoKeys = ["⌘", "I"]
    static let copyPathKeys = ["⌘", "⇧", "C"]
    static let quitKeys = ["⌘", "Q"]
    private static let showInfoService = "Finder/Show Info"
    private static let servicePasteboard = NSPasteboard.Name("com.taroj1205.mado.show-info")

    static func showInfo(_ url: URL) -> CommandAction {
        CommandAction(id: "show-info", title: "Show Info in Finder") {
            let pasteboard = NSPasteboard(name: servicePasteboard)
            pasteboard.clearContents()
            pasteboard.setString(url.absoluteString, forType: .fileURL)
            guard NSPerformService(showInfoService, pasteboard) else {
                throw CocoaError(.featureUnsupported)
            }
        }
    }

    static func copyPath(_ url: URL) -> CommandAction {
        CommandAction(id: "copy-path", title: "Copy Path") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url.path, forType: .string)
        }
    }

    static func quit(appAt url: URL) -> CommandAction? {
        guard let id = Bundle(url: url)?.bundleIdentifier else { return nil }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: id)
        guard !running.isEmpty else { return nil }
        return CommandAction(id: "quit", title: "Quit Application") {
            for app in running {
                app.terminate()
            }
        }
    }

    static func applications(toOpen url: URL) -> [URL] {
        let workspace = NSWorkspace.shared
        let preferred = workspace.urlForApplication(toOpen: url).map { [$0] } ?? []
        var seen: Set<String> = []
        return (preferred + workspace.urlsForApplications(toOpen: url)).filter { app in
            seen.insert(Bundle(url: app)?.bundleIdentifier ?? app.path).inserted
        }
    }

    static func open(_ url: URL, with app: URL) -> CommandAction {
        CommandAction(id: "open-with", title: AppIndex.name(of: app)) {
            _ = try await NSWorkspace.shared.open(
                [url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}
