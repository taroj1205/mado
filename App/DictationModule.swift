import AppCore
import InputKit
import os

struct DictationModule: Module {
    static let id = "dictation"

    let descriptor: ModuleDescriptor
    let settings: @MainActor () -> DictationSettings

    func start(context: ModuleContext) {
        context.startKeyFeatures {
            let dictation = Dictation(logger: context.logger, settings: settings)
            context.own(.other, "dictation") { dictation.stop() }
            context.installWhenTrusted("dictation key") {
                do {
                    try PushToTalk.install(
                        Dictation.key, name: "dictation key", context: context,
                        isActive: { dictation.isActive },
                        onEvent: context.untilStopped(dictation.handle))
                    return true
                } catch {
                    return false
                }
            }
        }
    }

    func stop() {
        Log.logger(descriptor.id).debug("Stopped")
    }
}
