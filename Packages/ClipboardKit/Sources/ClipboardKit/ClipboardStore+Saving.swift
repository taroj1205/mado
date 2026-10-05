import CryptoKit
public import Foundation
import UniformTypeIdentifiers

extension ClipboardStore {
    private enum SavedColumn: Int32 {
        case id = 0
        case kind = 1
        case type = 2
        case text = 3
        case data = 4
        case image = 5
    }

    private static func digest(
        _ kind: Clip.Kind, type: String?, text: String, data: Data?
    ) -> Data {
        var hash = SHA256()
        let parts = [Data(kind.rawValue.utf8), type.map { Data($0.utf8) }, Data(text.utf8), data]
        for part in parts {
            hash.update(data: Data("\(part?.count ?? -1):".utf8))
            hash.update(data: part ?? Data())
        }
        return Data(hash.finalize())
    }

    private static func digest(of clip: Clip) -> Data {
        digest(
            clip.kind, type: clip.type, text: clip.kind == .image ? "" : clip.text, data: clip.data)
    }

    public func mergeSavedDuplicates() throws {
        let digests = try missingDigests()
        guard !digests.isEmpty else { return }
        let removed: [String]
        do {
            try database.execute("BEGIN")
            for (id, digest) in digests {
                try database.run(
                    "UPDATE clips SET digest = ? WHERE id = ?", [.blob(digest), .integer(Int(id))])
            }
            removed = try database.rows(
                """
                DELETE FROM clips WHERE pinned = 0 AND EXISTS (
                    SELECT 1 FROM clips AS kept WHERE kept.digest = clips.digest
                        AND kept.id != clips.id
                        AND (kept.pinned = 1 OR (kept.date, kept.id) > (clips.date, clips.id))
                ) RETURNING image
                """,
                []
            ) { $0.string(0) }
            try database.execute("COMMIT")
        } catch {
            try? database.execute("ROLLBACK")
            throw error
        }
        for image in removed {
            try? FileManager.default.removeItem(at: images.appending(path: image))
        }
    }

    public func add(_ clip: Clip, keeping retention: Retention) throws {
        let digest = Self.digest(of: clip)
        if try !moveToTop(clip, matching: digest), try !foldIntoSameText(clip, digest: digest) {
            try insert(clip, digest: digest)
        }
        try prune(keeping: retention, now: clip.date)
    }

    public func bringToTop(id: Int64, at date: Date) throws {
        try database.run(
            "UPDATE clips SET date = ? WHERE id = ?",
            [.real(date.timeIntervalSince1970), .integer(Int(id))])
    }

    private func insert(_ clip: Clip, digest: Data) throws {
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
                "INSERT INTO clips (kind, text, type, data, image, source, date, digest)"
                    + " VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                [
                    .text(clip.kind.rawValue), .text(clip.text), .text(clip.type), .blob(data),
                    .text(image), .text(clip.source), .real(clip.date.timeIntervalSince1970),
                    .blob(digest),
                ])
        } catch {
            if let image {
                try? FileManager.default.removeItem(at: images.appending(path: image))
            }
            throw error
        }
    }

    private func missingDigests() throws -> [Int64: Data] {
        let rows = try database.rows(
            "SELECT id, kind, type, text, data, image FROM clips WHERE digest IS NULL", []
        ) { row -> (Int64, Data)? in
            guard let kind = row.string(SavedColumn.kind.rawValue).flatMap(Clip.Kind.init) else {
                return nil
            }
            var text = row.string(SavedColumn.text.rawValue) ?? ""
            var data = row.data(SavedColumn.data.rawValue)
            if let image = row.string(SavedColumn.image.rawValue) {
                text = ""
                data = (try? Data(contentsOf: images.appending(path: image))) ?? Data(image.utf8)
            }
            return (
                row.integer(SavedColumn.id.rawValue),
                Self.digest(
                    kind, type: row.string(SavedColumn.type.rawValue), text: text, data: data)
            )
        }
        return Dictionary(uniqueKeysWithValues: rows)
    }

    private func moveToTop(_ clip: Clip, matching digest: Data) throws -> Bool {
        try !database.rows(
            "UPDATE clips SET date = ?, source = ? WHERE digest = ? RETURNING id",
            [.real(clip.date.timeIntervalSince1970), .text(clip.source), .blob(digest)]
        ) { $0.integer(0) }
        .isEmpty
    }

    private func foldIntoSameText(_ clip: Clip, digest: Data) throws -> Bool {
        let newestSameText = """
            (SELECT id FROM clips WHERE kind = ? AND text = ?
                ORDER BY date DESC, id DESC LIMIT 1)
            """
        let date = Database.Value.real(clip.date.timeIntervalSince1970)
        let saved: [Int64]
        switch clip.kind {
        case .text:
            saved = try database.rows(
                "UPDATE clips SET date = ?, source = ? WHERE id = \(newestSameText) RETURNING id",
                [date, .text(clip.source), .text(Clip.Kind.richText.rawValue), .text(clip.text)]
            ) { $0.integer(0) }

        case .richText:
            saved = try database.rows(
                """
                UPDATE clips SET kind = ?, type = ?, data = ?, digest = ?, date = ?, source = ?
                    WHERE id = \(newestSameText) RETURNING id
                """,
                [
                    .text(clip.kind.rawValue), .text(clip.type), .blob(clip.data), .blob(digest),
                    date, .text(clip.source), .text(Clip.Kind.text.rawValue), .text(clip.text),
                ]
            ) { $0.integer(0) }

        case .image, .file, .url, .color:
            return false
        }
        return !saved.isEmpty
    }
}
