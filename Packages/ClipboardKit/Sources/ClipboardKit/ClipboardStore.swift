public import Foundation
import UniformTypeIdentifiers

public actor ClipboardStore {
    public struct Retention: Equatable, Sendable {
        public let days: Int
        public let items: Int

        public init(days: Int = 30, items: Int = 1_000) {
            self.days = days
            self.items = items
        }
    }

    public struct Entry: Equatable, Sendable {
        public let id: Int64
        public let kind: Clip.Kind
        public let text: String
        public let type: String?
        public let data: Data?
        public let image: URL?
        public let source: String?
        public let date: Date
    }

    private enum Column: Int32, CaseIterable {
        case id = 0
        case kind = 1
        case text = 2
        case type = 3
        case data = 4
        case image = 5
        case source = 6
        case date = 7
    }

    static let fileName = "history.sqlite"

    private static let schema = """
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
        """
    private static let columns = Column.allCases.map { "\($0)" }.joined(separator: ", ")
    private static let secondsPerDay: TimeInterval = 86_400

    private let images: URL
    private let database: Database

    public init(directory: URL) throws {
        images = directory.appending(path: "Images")
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        database = try Database(
            path: directory.appending(path: Self.fileName).path(percentEncoded: false))
        try database.execute(Self.schema)
    }

    public static func standard() throws -> ClipboardStore {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        #if DEBUG
            let name = "Clipboard.debug"
        #else
            let name = "Clipboard"
        #endif
        return try ClipboardStore(directory: base.appending(path: "Mado/\(name)"))
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
        let oldest = now.timeIntervalSince1970 - Double(retention.days) * Self.secondsPerDay
        let removed = try database.rows(
            "DELETE FROM clips WHERE date < ? OR id NOT IN"
                + " (SELECT id FROM clips ORDER BY date DESC, id DESC LIMIT ?) RETURNING image",
            [.real(oldest), .integer(retention.items)]
        ) { $0.string(0) }
        for image in removed {
            try? FileManager.default.removeItem(at: images.appending(path: image))
        }
    }

    public func search(_ query: String, limit: Int) throws -> [Entry] {
        let escaped =
            query
            .replacing("\\", with: "\\\\")
            .replacing("%", with: "\\%")
            .replacing("_", with: "\\_")
        return try database.rows(
            "SELECT \(Self.columns) FROM clips WHERE text LIKE ? ESCAPE '\\'"
                + " ORDER BY date DESC, id DESC LIMIT ?",
            [.text("%\(escaped)%"), .integer(limit)],
            entry)
    }

    private func entry(_ row: Database.Row) -> Entry? {
        guard let kind = row.string(Column.kind.rawValue).flatMap(Clip.Kind.init) else {
            return nil
        }
        return Entry(
            id: row.integer(Column.id.rawValue), kind: kind,
            text: row.string(Column.text.rawValue) ?? "", type: row.string(Column.type.rawValue),
            data: row.data(Column.data.rawValue),
            image: row.string(Column.image.rawValue).map { images.appending(path: $0) },
            source: row.string(Column.source.rawValue),
            date: Date(timeIntervalSince1970: row.real(Column.date.rawValue)))
    }
}
