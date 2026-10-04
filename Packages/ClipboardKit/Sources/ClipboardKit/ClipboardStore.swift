public import Foundation
import UniformTypeIdentifiers

public actor ClipboardStore {
    public struct Usage: Equatable, Sendable {
        public let items: Int
        public let bytes: Int
    }

    public struct Entry: Equatable, Sendable {
        public let id: Int64
        public let kind: Clip.Kind
        public let text: String
        public let type: String?
        public let files: [URL]
        public let image: URL?
        public let source: String?
        public let date: Date
        public let pinned: Bool
    }

    private enum Column: Int32, CaseIterable {
        case id = 0
        case kind = 1
        case text = 2
        case type = 3
        case files = 4
        case image = 5
        case source = 6
        case date = 7
        case pinned = 8
    }

    static let fileName = "history.sqlite"

    private static let migrations = [
        """
        CREATE TABLE IF NOT EXISTS clips (
            id INTEGER PRIMARY KEY,
            kind TEXT NOT NULL,
            text TEXT NOT NULL,
            type TEXT,
            data BLOB,
            image TEXT,
            source TEXT,
            date REAL NOT NULL
        );
        CREATE INDEX IF NOT EXISTS clips_by_date ON clips (date);
        """,
        "ALTER TABLE clips ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0;",
    ]
    private static let unpinnedIndex =
        "CREATE INDEX IF NOT EXISTS clips_unpinned_by_date ON clips (date) WHERE pinned = 0"
    private static let columns = Column.allCases.map { column in
        column == .files ? "CASE kind WHEN '\(Clip.Kind.file.rawValue)' THEN data END" : "\(column)"
    }
    .joined(separator: ", ")

    @MainActor private static var shared: ClipboardStore?

    private let images: URL
    private let database: Database

    public init(directory: URL) throws {
        images = directory.appending(path: "Images")
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        database = try Database(
            path: directory.appending(path: Self.fileName).path(percentEncoded: false))
        try database.execute("PRAGMA secure_delete = ON")
        try Self.migrate(database)
        try database.execute(Self.unpinnedIndex)
    }

    @MainActor
    public static func standard() throws -> ClipboardStore {
        if let shared {
            return shared
        }
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        #if DEBUG
            let name = "Clipboard.debug"
        #else
            let name = "Clipboard"
        #endif
        let store = try ClipboardStore(directory: base.appending(path: "Mado/\(name)"))
        shared = store
        return store
    }

    private static func migrate(_ database: Database) throws {
        let version = try database.rows("PRAGMA user_version", []) { Int($0.integer(0)) }.first ?? 0
        for (index, migration) in migrations.enumerated().dropFirst(version) {
            do {
                try database.execute(
                    "BEGIN; \(migration) PRAGMA user_version = \(index + 1); COMMIT;")
            } catch {
                try? database.execute("ROLLBACK")
                throw error
            }
        }
    }

    private static func files(_ kind: Clip.Kind, list: Data?, text: String) -> [URL] {
        guard kind == .file else { return [] }
        let saved = list.flatMap { String(bytes: $0, encoding: .utf8) }
        let paths = saved?.split(separator: Clip.pathSeparator) ?? text.split(separator: "\n")
        return paths.map { URL(filePath: String($0)) }
    }

    public func add(_ clip: Clip, keeping retention: Retention) throws {
        var image: String?
        var data = clip.data
        if clip.kind == .image, let bytes = data {
            let name = clip.type.flatMap { UTType($0)?.preferredFilenameExtension }
            let file = [UUID().uuidString, name].compactMap(\.self).joined(separator: ".")
            try bytes.write(to: images.appending(path: file))
            image = file
            data = nil
        }
        do {
            try database.run(
                "INSERT INTO clips (kind, text, type, data, image, source, date)"
                    + " VALUES (?, ?, ?, ?, ?, ?, ?)",
                [
                    .text(clip.kind.rawValue), .text(clip.text), .text(clip.type), .blob(data),
                    .text(image), .text(clip.source), .real(clip.date.timeIntervalSince1970),
                ])
        } catch {
            if let image {
                try? FileManager.default.removeItem(at: images.appending(path: image))
            }
            throw error
        }
        try prune(keeping: retention, now: clip.date)
    }

    public func prune(keeping retention: Retention, now: Date) throws {
        var removed: [String] = []
        if let oldest = retention.period?.start(before: now, in: .current) {
            removed += try database.rows(
                "DELETE FROM clips WHERE pinned = 0 AND date < ? RETURNING image",
                [.real(oldest.timeIntervalSince1970)]
            ) { $0.string(0) }
        }
        if let items = retention.items, let first = try newestUnpinned(skipping: items) {
            removed += try database.rows(
                "DELETE FROM clips WHERE pinned = 0 AND (date, id) <= (?, ?) RETURNING image",
                [.real(first.date), .integer(Int(first.id))]
            ) { $0.string(0) }
        }
        for image in removed {
            try? FileManager.default.removeItem(at: images.appending(path: image))
        }
    }

    private func newestUnpinned(skipping count: Int) throws -> (date: Double, id: Int64)? {
        try database.rows(
            "SELECT date, id FROM clips WHERE pinned = 0 ORDER BY date DESC, id DESC"
                + " LIMIT 1 OFFSET ?",
            [.integer(count)]
        ) { (date: $0.real(0), id: $0.integer(1)) }
        .first
    }

    public func clear() throws {
        try database.run("DELETE FROM clips WHERE pinned = 0", [])
        let kept = try Set(
            database.rows("SELECT image FROM clips WHERE image IS NOT NULL", []) { $0.string(0) })
        let files = try FileManager.default.contentsOfDirectory(
            atPath: images.path(percentEncoded: false))
        var failure: (any Error)?
        for file in files where !kept.contains(file) {
            do {
                try FileManager.default.removeItem(at: images.appending(path: file))
            } catch {
                failure = failure ?? error
            }
        }
        try compact()
        if let failure {
            throw failure
        }
    }

    public func compact() throws {
        try database.execute("VACUUM")
    }

    public func usage() throws -> Usage {
        let items = try database.rows("SELECT COUNT(*) FROM clips", []) { Int($0.integer(0)) }
        let files = try FileManager.default.contentsOfDirectory(
            at: images, includingPropertiesForKeys: [.totalFileAllocatedSizeKey])
        let history = images.deletingLastPathComponent().appending(path: Self.fileName)
        let bytes = try ([history] + files).reduce(0) { total, file in
            try total
                + (file.resourceValues(forKeys: [.totalFileAllocatedSizeKey])
                    .totalFileAllocatedSize ?? 0)
        }
        return Usage(items: items.first ?? 0, bytes: bytes)
    }

    public func setPinned(_ pinned: Bool, id: Int64) throws {
        try database.run(
            "UPDATE clips SET pinned = ? WHERE id = ?",
            [.integer(pinned ? 1 : 0), .integer(Int(id))])
    }

    public func search(
        _ query: String, limit: Int, kind: Clip.Kind? = nil, source: String? = nil
    ) throws -> [Entry] {
        let escaped =
            query
            .replacing("\\", with: "\\\\")
            .replacing("%", with: "\\%")
            .replacing("_", with: "\\_")
        var conditions = ["text LIKE ? ESCAPE '\\'"]
        var values: [Database.Value] = [.text("%\(escaped)%")]
        if let kind {
            conditions.append("kind = ?")
            values.append(.text(kind.rawValue))
        }
        if let source {
            conditions.append("source = ?")
            values.append(.text(source))
        }
        return try database.rows(
            "SELECT \(Self.columns) FROM clips WHERE \(conditions.joined(separator: " AND "))"
                + " ORDER BY date DESC, id DESC LIMIT ?",
            values + [.integer(limit)],
            entry)
    }

    public func data(for id: Int64) throws -> Data? {
        try database.rows("SELECT data FROM clips WHERE id = ?", [.integer(Int(id))]) { row in
            row.data(0)
        }
        .first
    }

    public func sources() throws -> [String] {
        try database.rows(
            "SELECT source FROM clips WHERE source IS NOT NULL"
                + " GROUP BY source ORDER BY MAX(date) DESC",
            []
        ) { $0.string(0) }
    }

    private func entry(_ row: Database.Row) -> Entry? {
        guard let kind = row.string(Column.kind.rawValue).flatMap(Clip.Kind.init) else {
            return nil
        }
        let text = row.string(Column.text.rawValue) ?? ""
        return Entry(
            id: row.integer(Column.id.rawValue), kind: kind, text: text,
            type: row.string(Column.type.rawValue),
            files: Self.files(kind, list: row.data(Column.files.rawValue), text: text),
            image: row.string(Column.image.rawValue).map { images.appending(path: $0) },
            source: row.string(Column.source.rawValue),
            date: Date(timeIntervalSince1970: row.real(Column.date.rawValue)),
            pinned: row.integer(Column.pinned.rawValue) != 0)
    }
}
