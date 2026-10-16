public import Foundation

public struct FileSettings: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case added = "added_folders"
        case removed = "removed_folders"
    }

    public static let key = "files"

    private var added: [String]
    private var removed: [String]

    public var paths: [String] {
        FileIndex.folders.map(\.path).filter { !removed.contains($0) } + added
    }

    public var folders: [URL] {
        paths.map { URL(filePath: $0, directoryHint: .isDirectory) }
    }

    public init() {
        added = []
        removed = []
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        added = try values.decodeIfPresent([String].self, forKey: .added) ?? []
        removed = try values.decodeIfPresent([String].self, forKey: .removed) ?? []
    }

    public mutating func add(_ path: String) {
        guard !paths.contains(path) else { return }
        if removed.contains(path) {
            removed.removeAll { $0 == path }
        } else {
            added.append(path)
        }
    }

    public mutating func remove(_ path: String) {
        guard paths.contains(path) else { return }
        if added.contains(path) {
            added.removeAll { $0 == path }
        } else {
            removed.append(path)
        }
    }
}
