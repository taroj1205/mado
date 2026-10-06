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
        var check: (@MainActor () -> Void)?

        init(pasteboard: NSPasteboard) {
            self.pasteboard = pasteboard
        }

        func start(context: ModuleContext) {
            check = PasteboardWatch.install(
                name: "pasteboard watch", context: context, pasteboard: pasteboard
            ) { [weak self] _ in self?.changes += 1 }
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

    @Test func takesTheSourceFromTheMarkerOrTheAppsInFrontSinceTheLastPoll() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let front = "com.example.front"
        let switched = "com.example.switched"

        pasteboard.setString("copied", forType: .string)
        let stayed = PasteboardWatch.sourceApps(of: pasteboard, frontmost: front, before: front)
        let moved = PasteboardWatch.sourceApps(of: pasteboard, frontmost: switched, before: front)
        let none = PasteboardWatch.sourceApps(of: pasteboard, frontmost: nil, before: nil)
        pasteboard.setString("com.example.source", forType: PasteboardWatch.sourceType)
        let marked = PasteboardWatch.sourceApps(of: pasteboard, frontmost: front, before: front)
        pasteboard.setString("", forType: PasteboardWatch.sourceType)
        let unknown = PasteboardWatch.sourceApps(of: pasteboard, frontmost: front, before: front)

        #expect(stayed == [front])
        #expect(moved == [front, switched])
        #expect(none.isEmpty)
        #expect(marked == ["com.example.source"])
        #expect(unknown.isEmpty)
    }

    @Test func keepsTheAppFromTheLastPollThroughSeveralSwitches() {
        var front = PasteboardWatch.FrontApps(current: "com.example.front")

        front.activate("com.example.first")
        front.activate("com.example.second")
        let beforePoll = (front.current, front.polled)
        front.poll()
        let afterPoll = (front.current, front.polled)

        #expect(beforePoll == ("com.example.second", "com.example.front"))
        #expect(afterPoll == ("com.example.second", "com.example.second"))
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

    @Test func aCheckReportsACopyBeforeTheNextPoll() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let manager = try ModuleManager(
            store: SettingsStore(url: dir.appending(path: "settings.json")))
        let module = WatchingModule(pasteboard: pasteboard)
        try manager.register(module)
        try manager.setEnabled("clipboard", true)
        let check = try #require(module.check)

        pasteboard.clearContents()
        pasteboard.setString("copied", forType: .string)
        check()
        let afterCheck = module.changes
        check()

        #expect(afterCheck == 1)
        #expect(module.changes == 1)
        try manager.setEnabled("clipboard", false)
    }

    @Test func aCopyJustBeforeTheModuleStopsIsStillReported() throws {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let manager = try ModuleManager(
            store: SettingsStore(url: dir.appending(path: "settings.json")))
        let module = WatchingModule(pasteboard: pasteboard)
        try manager.register(module)
        try manager.setEnabled("clipboard", true)

        pasteboard.clearContents()
        pasteboard.setString("copied", forType: .string)
        try manager.restart("clipboard")
        try manager.setEnabled("clipboard", false)

        #expect(module.changes == 1)
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
                ActiveResource(
                    module: "clipboard", kind: .observer,
                    name: NSWorkspace.didActivateApplicationNotification.rawValue),
                ActiveResource(module: "clipboard", kind: .timer, name: "pasteboard watch"),
                ActiveResource(
                    module: "clipboard", kind: .other, name: "pasteboard watch last check"),
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
