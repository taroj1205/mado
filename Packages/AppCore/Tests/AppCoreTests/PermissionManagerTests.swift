import AVFoundation
import Foundation
import Testing

@testable import AppCore

@MainActor
@Suite struct PermissionManagerTests {
    final class OpenedURLs {
        var urls: [URL] = []
    }

    func makeManager(_ probe: FakeProbe, opened: OpenedURLs) -> PermissionManager {
        PermissionManager(probe: probe, interval: .milliseconds(10)) { opened.urls.append($0) }
    }

    func makeManager(_ probe: FakeProbe) -> PermissionManager {
        makeManager(probe, opened: OpenedURLs())
    }

    @Test func readsInitialStatuses() {
        let probe = FakeProbe()
        probe.set(.accessibility, .granted)
        probe.set(.microphone, .notDetermined)
        let manager = makeManager(probe)
        #expect(manager.status(for: .accessibility) == .granted)
        #expect(manager.status(for: .inputMonitoring) == .denied)
        #expect(manager.status(for: .screenRecording) == .denied)
        #expect(manager.status(for: .microphone) == .notDetermined)
    }

    @Test func refreshReflectsToggling() {
        let probe = FakeProbe()
        let manager = makeManager(probe)
        probe.set(.screenRecording, .granted)
        #expect(manager.status(for: .screenRecording) == .denied)
        manager.refresh()
        #expect(manager.status(for: .screenRecording) == .granted)
        probe.set(.screenRecording, .denied)
        manager.refresh()
        #expect(manager.status(for: .screenRecording) == .denied)
    }

    @Test func calendarsAreNotManaged() {
        let probe = FakeProbe()
        probe.set(.calendars, .granted)
        let manager = makeManager(probe)
        #expect(!PermissionManager.managed.contains(.calendars))
        #expect(manager.statuses[.calendars] == nil)
    }

    @Test func pollingRunsOnlyWhileWatched() async throws {
        let probe = FakeProbe()
        let manager = makeManager(probe)
        #expect(!manager.isPolling)
        manager.beginWatching()
        #expect(manager.isPolling)
        probe.set(.inputMonitoring, .granted)
        try await waitUntil { manager.status(for: .inputMonitoring) == .granted }
        manager.endWatching()
        #expect(!manager.isPolling)
        probe.set(.inputMonitoring, .denied)
        try await Task.sleep(for: .milliseconds(80))
        #expect(manager.status(for: .inputMonitoring) == .granted)
    }

    @Test func overlappingScreensShareOnePoll() {
        let manager = makeManager(FakeProbe())
        manager.beginWatching()
        manager.beginWatching()
        manager.endWatching()
        #expect(manager.isPolling)
        manager.endWatching()
        #expect(!manager.isPolling)
        manager.endWatching()
        #expect(!manager.isPolling)
    }

    @Test func opensSettingsPane() {
        let opened = OpenedURLs()
        let manager = makeManager(FakeProbe(), opened: opened)
        for permission in PermissionManager.managed {
            manager.openSettings(for: permission)
        }
        let base = "x-apple.systempreferences:com.apple.preference.security?"
        #expect(
            opened.urls.map(\.absoluteString) == [
                base + "Privacy_Accessibility",
                base + "Privacy_ListenEvent",
                base + "Privacy_ScreenCapture",
                base + "Privacy_Microphone",
            ])
    }

    @Test func requestAsksTheSystemAndReadsTheAnswer() async {
        let probe = FakeProbe()
        probe.set(.microphone, .notDetermined)
        probe.answer(.microphone, with: .granted)
        let manager = makeManager(probe)
        #expect(await manager.request(.microphone) == .granted)
        #expect(manager.statuses[.microphone] == .granted)
        #expect(probe.requests == [.microphone])
    }

    @Test func mapsMicrophoneStatus() {
        #expect(SystemPermissionProbe.microphone(.authorized) == .granted)
        #expect(SystemPermissionProbe.microphone(.notDetermined) == .notDetermined)
        #expect(SystemPermissionProbe.microphone(.denied) == .denied)
        #expect(SystemPermissionProbe.microphone(.restricted) == .denied)
    }

    @Test func calendarsHaveNoSystemStatus() {
        #expect(SystemPermissionProbe().status(for: .calendars) == .unsupported)
    }

    func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0..<200 where !condition() {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition())
    }
}
