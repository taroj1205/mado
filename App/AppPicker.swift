import AppKit
import UniformTypeIdentifiers

@MainActor
enum AppPicker {
    static func pick(from sender: NSButton, then add: @escaping (URL) -> Void) {
        guard let window = unsafe sender.window else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(filePath: "/Applications")
        panel.prompt = "Add"
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let app = panel.url else { return }
            add(app)
        }
    }

    static func pickBundleID(from sender: NSButton, then add: @escaping (String) -> Void) {
        pick(from: sender) { app in
            guard let id = Bundle(url: app)?.bundleIdentifier else {
                NSApp.presentError(CocoaError(.fileReadCorruptFile, userInfo: [NSURLErrorKey: app]))
                return
            }
            add(id)
        }
    }
}
