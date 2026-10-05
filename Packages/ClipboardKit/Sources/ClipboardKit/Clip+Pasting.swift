public import AppKit

extension Clip {
    private static let titleLimit = 200

    public var title: String {
        Self.title(kind, text: text, files: files)
    }

    var files: [URL] {
        ClipboardStore.files(kind, list: data, text: text)
    }

    static func title(_ kind: Kind, text: String, files: [URL]) -> String {
        switch kind {
        case .image:
            return kind.title

        case .file:
            return files.map(\.lastPathComponent).joined(separator: ", ")

        case .text, .richText, .url, .color:
            var line = ""
            text.enumerateLines { candidate, stop in
                line = candidate.trimmingCharacters(in: .whitespaces)
                stop = !line.isEmpty
            }
            return String(line.prefix(titleLimit))
        }
    }

    @MainActor
    static func pasteboardItems(
        _ kind: Kind, text: String, type: String?, data: Data?, files: [URL]
    ) throws -> [NSPasteboardItem] {
        let items: [NSPasteboardItem]
        switch kind {
        case .file:
            items = files.map { file in
                let item = NSPasteboardItem()
                item.setString(file.absoluteString, forType: .fileURL)
                return item
            }

        case .image:
            guard let data, let type else { throw PasteTarget.Failure.notWritten }
            let item = NSPasteboardItem()
            item.setData(data, forType: .init(type))
            items = [item]

        case .text, .richText, .url, .color:
            let item = NSPasteboardItem()
            item.setString(text, forType: .string)
            if kind == .url {
                item.setString(text, forType: .URL)
            }
            if let type, let data {
                item.setData(data, forType: .init(type))
            }
            items = [item]
        }
        items.first?.setData(Data(), forType: PasteboardWatch.transientType)
        return items
    }

    @MainActor
    public static func savedTextItems(_ text: String, source: String?) -> [NSPasteboardItem] {
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        if let source {
            item.setString(source, forType: PasteboardWatch.sourceType)
        }
        return [item]
    }

    @MainActor
    public static func copyText(_ text: String, source: String?) throws {
        try PasteTarget.write(savedTextItems(text, source: source), to: .general)
    }

    @MainActor
    public func copy(to pasteboard: NSPasteboard = .general) throws {
        try PasteTarget.write(
            Self.pasteboardItems(kind, text: text, type: type, data: data, files: files),
            to: pasteboard)
    }
}
