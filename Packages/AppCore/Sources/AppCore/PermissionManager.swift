import AppKit
public import Foundation
public import Observation

@MainActor
@Observable
public final class PermissionManager {
    public static let managed: [Permission] = [
        .accessibility, .inputMonitoring, .screenRecording, .microphone,
    ]

    public private(set) var statuses: [Permission: PermissionStatus] = [:]
    public private(set) var isPolling = false

    @ObservationIgnored private let probe: any PermissionProbe
    @ObservationIgnored private let interval: Duration
    @ObservationIgnored private let open: @MainActor (URL) -> Void
    @ObservationIgnored private var watchers = 0
    @ObservationIgnored private var task: Task<Void, Never>?

    public init(
        probe: (any PermissionProbe)? = nil,
        interval: Duration = .seconds(1),
        open: (@MainActor (URL) -> Void)? = nil
    ) {
        self.probe = probe ?? SystemPermissionProbe()
        self.interval = interval
        self.open = open ?? { NSWorkspace.shared.open($0) }
        refresh()
    }

    public static func settingsURL(for permission: Permission) -> URL {
        let anchor =
            switch permission {
            case .accessibility: "Privacy_Accessibility"
            case .calendars: "Privacy_Calendars"
            case .inputMonitoring: "Privacy_ListenEvent"
            case .microphone: "Privacy_Microphone"
            case .screenRecording: "Privacy_ScreenCapture"
            }
        return URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")
            ?? URL(filePath: "/System/Applications/System Settings.app")
    }

    public func status(for permission: Permission) -> PermissionStatus {
        statuses[permission] ?? probe.status(for: permission)
    }

    public func refresh() {
        for permission in Self.managed {
            let current = probe.status(for: permission)
            if statuses[permission] != current {
                statuses[permission] = current
            }
        }
    }

    public func request(_ permission: Permission) async -> PermissionStatus {
        let current = await probe.request(permission)
        statuses[permission] = current
        return current
    }

    public func openSettings(for permission: Permission) {
        open(Self.settingsURL(for: permission))
    }

    public func beginWatching() {
        watchers += 1
        guard task == nil else { return }
        refresh()
        isPolling = true
        let delay = interval
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return }
                self?.refresh()
            }
        }
    }

    public func endWatching() {
        guard watchers > 0 else { return }
        watchers -= 1
        guard watchers == 0 else { return }
        task?.cancel()
        task = nil
        isPolling = false
    }
}
