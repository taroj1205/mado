import AppCore
import GlassUI
import InputKit
import os
import WindowKit

struct WindowsModule: Module {
    static let id = "windows"
    private static let radialTrigger: Shortcut.Modifiers = [.function]

    let descriptor: ModuleDescriptor
    let radialSettings: @MainActor () -> RadialSettings
    let radialRing = OverlayPanel()
    let radialPreview = SnapPreview()

    func start(context: ModuleContext) {
        let radialMenu = RadialMenu(
            logger: context.logger, panel: radialRing, preview: radialPreview,
            settings: radialSettings)
        context.own(.other, "radial menu") { radialMenu.stop() }
        context.installWhenTrusted("radial trigger") {
            do {
                try ModifierTrigger.install(
                    Self.radialTrigger, name: "radial trigger", context: context,
                    onEvent: radialMenu.handle)
                return true
            } catch {
                return false
            }
        }
        context.logger.debug("Started")
    }

    func stop() {
        Log.logger(descriptor.id).debug("Stopped")
    }
}
