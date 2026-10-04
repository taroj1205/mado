import AppCore
import ClipboardKit
import GlassUI
import InputKit
import os
import SearchKit
import WindowKit

protocol StoredValue: Codable {
    static var key: String { get }

    init()
}

extension StoredValue {
    @MainActor
    static func load(from modules: ModuleManager?) -> Self {
        do {
            return try modules?.value(Self.self, for: key) ?? Self()
        } catch {
            Log.logger("App").error(
                "\(key, privacy: .public) failed to load: \(error, privacy: .public)")
            return Self()
        }
    }

    @MainActor
    func save(to modules: ModuleManager?) {
        do {
            try modules?.setValue(self, for: Self.key)
        } catch {
            Log.logger("App").error(
                "Saving \(Self.key, privacy: .public) failed: \(error, privacy: .public)")
        }
    }
}

extension Usage: StoredValue {
    static let key = "usage"
}

extension ItemSettings: StoredValue {
    static let key = "items"
}

extension AnswerSettings: StoredValue {
    static let key = "answers"
}

extension Quicklinks: StoredValue {
    static let key = "quicklinks"
}

extension RadialSettings: StoredValue {
    static let key = "radial"
}

extension StatusBarLayout: StoredValue {
    static let key = "status_bar"
}

extension ClipboardSettings: StoredValue {
    static let key = "clipboard"
}

extension SnippetSettings: StoredValue {
    static let key = "snippets"
}

extension InputSourceSettings: StoredValue {
    static let key = "input_sources"
}

extension GestureSettings: StoredValue {
    static let key = "gestures"
}

extension GestureSettings.Target {
    var title: String {
        switch self {
        case .activeWindow: "Active Window"
        case .underMouse: "Window Under Mouse"
        }
    }
}

extension RemapSettings: StoredValue {
    static let key = "remaps"
}

extension WidgetSettings: StoredValue {
    static let key = "widgets"
}
