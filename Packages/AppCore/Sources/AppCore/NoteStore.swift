public import Foundation

public struct NoteStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    public static func standard() throws -> Self {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        #if DEBUG
            let name = "Notes.debug"
        #else
            let name = "Notes"
        #endif
        return Self(directory: base.appending(path: "Mado/\(name)", directoryHint: .isDirectory))
    }

    public func load() throws -> [Note] {
        guard FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) else {
            return []
        }
        let entries = try FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil)
        let files = entries.filter { $0.pathExtension == "json" }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return files.compactMap { try? decoder.decode(Note.self, from: Data(contentsOf: $0)) }
            .sorted { ($0.modified, $0.id.uuidString) < ($1.modified, $1.id.uuidString) }
    }

    public func save(_ note: Note) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try encoder.encode(note).write(to: file(of: note.id), options: .atomic)
    }

    private func file(of id: Note.ID) -> URL {
        directory.appending(path: "\(id.uuidString).json", directoryHint: .notDirectory)
    }
}
