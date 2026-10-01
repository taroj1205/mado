import AppCore
public import AppKit
import os

@MainActor
public final class AppIndex {
    public struct App: Sendable, Equatable {
        public let name: String
        public let folder: String
        public let url: URL

        public var keys: [String] {
            [name, url.deletingPathExtension().lastPathComponent]
        }
    }

    private static let latency: TimeInterval = 0.5

    public static let folders = [
        URL(filePath: "/Applications"),
        URL(filePath: "/System/Applications"),
        URL.homeDirectory.appending(path: "Applications"),
    ]

    public private(set) var apps: [App] = []
    public var onChange: (() -> Void)?

    private let logger = Log.logger("AppIndex")
    private let folders: [URL]
    private var watcher: FolderWatcher?
    private var icons: [URL: NSImage] = [:]
    private(set) var scan: Task<Void, Never>?

    public init(folders: [URL] = AppIndex.folders) {
        self.folders = folders
    }

    nonisolated static func apps(in folders: [URL]) -> [App] {
        let files = FileManager.default
        var found: [App] = []
        for root in folders {
            guard
                let items = files.enumerator(
                    at: root, includingPropertiesForKeys: nil, options: .skipsPackageDescendants)
            else { continue }
            for case let url as URL in items {
                if url.lastPathComponent.hasPrefix(".") {
                    items.skipDescendants()
                    continue
                }
                guard url.pathExtension == "app" else { continue }
                let parent = url.deletingLastPathComponent().path
                found.append(
                    App(
                        name: name(files.displayName(atPath: url.path)),
                        folder: items.level == 1 ? "" : files.displayName(atPath: parent),
                        url: url))
            }
        }
        return found.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    nonisolated private static func name(_ displayName: String) -> String {
        displayName.replacing(/\.app$/, with: "")
    }

    public func start() {
        watcher = FolderWatcher(folders: folders, latency: Self.latency) { [weak self] in
            self?.refresh()
        }
        if watcher == nil {
            logger.error("Watching the app folders failed; installs show after relaunch")
        }
        refresh()
    }

    public func icon(for app: App) -> NSImage {
        if let icon = icons[app.url] {
            return icon
        }
        let icon = NSWorkspace.shared.icon(forFile: app.url.path)
        icons[app.url] = icon
        return icon
    }

    private func refresh() {
        scan?.cancel()
        scan = Task { [folders] in
            let found = await Task.detached { Self.apps(in: folders) }.value
            guard !Task.isCancelled else { return }
            icons = [:]
            guard found != apps else { return }
            apps = found
            onChange?()
        }
    }
}
