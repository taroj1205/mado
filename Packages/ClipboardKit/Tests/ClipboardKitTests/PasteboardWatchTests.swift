import AppCore
import AppKit
import Foundation
import Testing

@testable import ClipboardKit

@MainActor
@Suite struct PasteboardWatchTests {
    final class WatchingModule: Module {
        let descriptor = ModuleDescriptor(
            id: "clipboard", name: "Clipboard", enabledByDefault: false)
        let pasteboard: NSPasteboard
        var changes = 0
        var stops = 0

        init(pasteboard: NSPasteboard) {
            self.pasteboard = pasteboard
        }

        func start(context: ModuleContext) {
            PasteboardWatch.install(
                name: "pasteboard watch", context: context, pasteboard: pasteboard
            ) { [weak self] in self?.changes += 1 }
        }

        func stop() {
            stops += 1
        }
    }

    @Test func reportsEachChangeOnce() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("before", forType: .string)
        var watch = PasteboardWatch(pasteboard: pasteboard)

        let unchanged = watch.poll()
        pasteboard.clearContents()
        pasteboard.setString("after", forType: .string)
        let changed = watch.poll()
        let again = watch.poll()

        #expect([unchanged, changed, again] == [false, true, false])
    }

    @Test(arguments: PasteboardWatch.privateTypes)
    func flagsACopyMarkedPrivateOnAnyItem(_ marker: NSPasteboard.PasteboardType) {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let watch = PasteboardWatch(pasteboard: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString("username", forType: .string)
        let plainIsPrivate = watch.holdsPrivateData

        let plain = NSPasteboardItem()
        plain.setString("username", forType: .string)
        let secret = NSPasteboardItem()
        secret.setString("hunter2", forType: .string)
        secret.setData(Data(), forType: marker)
        pasteboard.clearContents()
        pasteboard.writeObjects([plain, secret])

        #expect(!plainIsPrivate)
        #expect(watch.holdsPrivateData)
    }

    @Test func watchesOnlyWhileTheModuleIsOn() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let manager = try ModuleManager(
            store: SettingsStore(url: dir.appending(path: "settings.json")))
        let module = WatchingModule(pasteboard: pasteboard)
        try manager.register(module)

        try manager.startEnabledModules()
        #expect(manager.activeResources.isEmpty)

        try manager.setEnabled("clipboard", true)
        #expect(
            manager.activeResources == [
                ActiveResource(module: "clipboard", kind: .timer, name: "pasteboard watch")
            ])

        pasteboard.clearContents()
        pasteboard.setString("hunter2", forType: .string)
        pasteboard.setData(Data(), forType: .init("org.nspasteboard.ConcealedType"))
        RunLoop.main.run(until: .now.addingTimeInterval(PasteboardWatch.interval * 3))
        #expect(module.changes == 0)

        pasteboard.clearContents()
        pasteboard.setString("copied", forType: .string)
        let deadline = Date.now.addingTimeInterval(PasteboardWatch.interval * 4)
        while module.changes == 0, Date.now < deadline {
            RunLoop.main.run(until: .now.addingTimeInterval(PasteboardWatch.interval / 5))
        }
        #expect(module.changes == 1)

        try manager.setEnabled("clipboard", false)
        #expect(module.stops == 1)
        #expect(manager.activeResources.isEmpty)
    }
}
