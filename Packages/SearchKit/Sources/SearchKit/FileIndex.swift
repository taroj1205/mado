import AppCore
public import Foundation
import os

@MainActor
public final class FileIndex {
    public struct File: Sendable, Equatable {
        public let name: String
        public let folder: String
        public let url: URL
        public let path: String
        public let key: Fuzzy.Key
        public let isFolder: Bool
        public let modified: Date?
    }

    private static let latency: TimeInterval = 5
    nonisolated private static let keys: [URLResourceKey] = [
        .isDirectoryKey, .isPackageKey, .contentModificationDateKey,
    ]
    private static let daysShownAsWeekday = 6

    public static let folders = [
        URL.desktopDirectory, URL.documentsDirectory, URL.downloadsDirectory,
    ]

    public private(set) var files: [File] = [] {
        didSet { byPath = Dictionary(files.map { ($0.path, $0) }) { first, _ in first } }
    }
    public var onChange: (() -> Void)?

    private let logger = Log.logger("FileIndex")
    private var byPath: [String: File] = [:]
    private let folders: [URL]
    private var watcher: FolderWatcher?
    private(set) var scan: Task<Void, Never>?

    public init(folders: [URL] = FileIndex.folders) {
        self.folders = folders
    }

    @concurrent nonisolated static func files(in folders: [URL]) async -> [File] {
        walk(folders)
    }

    @concurrent nonisolated public static func rank(
        _ files: [File], by query: String, items: ItemSettings, usage: Usage, at now: Date
    ) async -> [File] {
        let bonus = { usage.bonus(for: $0, at: now) }
        return items.rank(files, by: query, bonus: bonus, id: \.path) { [$0.key] }
    }

    nonisolated private static func walk(_ folders: [URL]) -> [File] {
        var found: [File] = []
        for root in folders {
            guard
                let items = FileManager.default.enumerator(
                    at: root, includingPropertiesForKeys: keys,
                    options: [.skipsHiddenFiles, .skipsPackageDescendants])
            else { continue }
            for case let url as URL in items {
                guard !Task.isCancelled else { return [] }
                let name = url.lastPathComponent
                let values = try? url.resourceValues(forKeys: Set(keys))
                found.append(
                    File(
                        name: name,
                        folder: abbreviated(url.deletingLastPathComponent()),
                        url: url, path: url.path, key: Fuzzy.Key(name),
                        isFolder: values?.isDirectory == true && values?.isPackage != true,
                        modified: values?.contentModificationDate))
            }
        }
        return found
    }

    nonisolated static func abbreviated(_ folder: URL) -> String {
        let path = folder.path
        let home = URL.homeDirectory.path
        guard path == home || path.hasPrefix(home + "/") else { return path }
        return "~" + path.dropFirst(home.count)
    }

    public static func kind(
        of file: File, at now: Date, in calendar: Calendar = .current
    ) -> String {
        if file.isFolder { return "Folder" }
        guard let edited = file.modified else { return "File" }
        let today = calendar.startOfDay(for: now)
        if edited >= today { return "Edited today" }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        if edited >= yesterday { return "Yesterday" }
        let style = Date.FormatStyle(
            locale: calendar.locale ?? .autoupdatingCurrent, calendar: calendar,
            timeZone: calendar.timeZone)
        let week = calendar.date(byAdding: .day, value: -daysShownAsWeekday, to: today) ?? today
        if edited >= week { return edited.formatted(style.weekday()) }
        return edited.formatted(style.day().month().year())
    }

    public func file(atPath path: String) -> File? {
        byPath[path]
    }

    public func start() {
        watcher = FolderWatcher(folders: folders, latency: Self.latency) { [weak self] in
            self?.refresh()
        }
        if watcher == nil {
            logger.error("Watching the file folders failed; new files show after relaunch")
        }
        refresh()
    }

    private func refresh() {
        scan?.cancel()
        scan = Task(priority: .background) { [folders] in
            let found = await Self.files(in: folders)
            guard !Task.isCancelled, found != files else { return }
            files = found
            onChange?()
        }
    }
}
