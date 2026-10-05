import AppCore
import GlassUI
import os

struct WidgetSnapshot {
    let settings: WidgetSettings
    let placement: WidgetPlacement

    @MainActor
    init(of modules: ModuleManager?) {
        settings = .load(from: modules)
        placement = .load(from: modules)
    }

    @MainActor
    func restore(to modules: ModuleManager?) {
        settings.save(to: modules)
        do {
            try placement.save(to: modules)
        } catch {
            Log.logger("Widgets").error("Placement failed to restore: \(error, privacy: .public)")
        }
    }
}
