import AppCore
import AVFoundation
import Foundation
import InputKit
import os

struct DictationModule: Module {
    static let id = "dictation"

    let descriptor: ModuleDescriptor

    func start(context: ModuleContext) {
        let permissions = PermissionManager()
        context.run("microphone permission") { _ = await permissions.request(.microphone) }
        let dictation = Dictation(context: context, permissions: permissions)
        context.own(.other, "dictation") { dictation.stop() }
        context.run("audio input changes") {
            let changes = NotificationCenter.default.notifications(
                named: .AVAudioEngineConfigurationChange)
            for await _ in changes {
                dictation.switchInput()
            }
        }
        context.installWhenTrusted("dictation key") {
            do {
                try PushToTalk.install(
                    .rightOption, name: "dictation key", context: context,
                    onEvent: dictation.handle)
                return true
            } catch {
                return false
            }
        }
    }

    func stop() {
        Log.logger(descriptor.id).debug("Stopped")
    }
}
