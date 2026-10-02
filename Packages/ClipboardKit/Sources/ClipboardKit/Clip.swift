public import AppKit

public struct Clip: Equatable, Sendable {
    public enum Kind: String, Sendable {
        case text = "text"
        case richText = "rich_text"
        case image = "image"
        case file = "file"
        case url = "url"
        case color = "color"
    }

    private struct Content {
        let kind: Kind
        let text: String
        let type: NSPasteboard.PasteboardType?
        let data: Data?
    }

    private static let imageTypes: [NSPasteboard.PasteboardType] = [.png, .tiff]
    private static let richTextTypes: [NSPasteboard.PasteboardType] = [.rtf, .html]
    private static let hexRadix = 16

    public let kind: Kind
    public let text: String
    public let type: String?
    public let data: Data?
    public let source: String?
    public let date: Date

    @MainActor
    public init?(reading pasteboard: NSPasteboard, source: String?, at date: Date) {
        let readers = [Self.fileContent, Self.colorContent, Self.imageContent, Self.textContent]
        guard let content = readers.lazy.compactMap({ $0(pasteboard) }).first else { return nil }
        self.init(
            content.kind, text: content.text, type: content.type, data: content.data,
            source: source, date: date)
    }

    init(
        _ kind: Kind, text: String, type: NSPasteboard.PasteboardType?, data: Data?,
        source: String?, date: Date
    ) {
        self.kind = kind
        self.text = text
        self.type = type?.rawValue
        self.data = data
        self.source = source
        self.date = date
    }

    private static func isWebLink(_ text: String) -> Bool {
        guard !text.contains(where: \.isWhitespace), let url = URL(string: text) else {
            return false
        }
        return ["http", "https"].contains(url.scheme?.lowercased()) && url.host() != nil
    }

    private static func hex(_ color: NSColor) -> String? {
        guard let rgb = color.usingColorSpace(.sRGB) else { return nil }
        let max = CGFloat(UInt8.max)
        let bytes = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent].map { part in
            let digits = String(Int((part * max).rounded()), radix: hexRadix, uppercase: true)
            return digits.count == 1 ? "0\(digits)" : digits
        }
        return "#\(bytes.joined())"
    }

    private static func fileContent(on pasteboard: NSPasteboard) -> Content? {
        let paths = (pasteboard.pasteboardItems ?? []).compactMap { item in
            item.string(forType: .fileURL).flatMap(URL.init(string:))?.path(percentEncoded: false)
        }
        guard !paths.isEmpty else { return nil }
        return Content(kind: .file, text: paths.joined(separator: "\n"), type: nil, data: nil)
    }

    private static func colorContent(on pasteboard: NSPasteboard) -> Content? {
        guard let color = NSColor(from: pasteboard), let code = hex(color) else { return nil }
        return Content(
            kind: .color, text: code, type: .color, data: pasteboard.data(forType: .color))
    }

    private static func imageContent(on pasteboard: NSPasteboard) -> Content? {
        guard pasteboard.availableType(from: [.string]) == nil,
            let format = pasteboard.availableType(from: imageTypes),
            let bytes = pasteboard.data(forType: format)
        else { return nil }
        return Content(kind: .image, text: "", type: format, data: bytes)
    }

    private static func textContent(on pasteboard: NSPasteboard) -> Content? {
        guard let string = pasteboard.string(forType: .string) ?? pasteboard.string(forType: .URL)
        else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }
        if trimmed.wholeMatch(of: /#([0-9a-f]{6}|[0-9a-f]{8})/.ignoresCase()) != nil {
            return Content(kind: .color, text: trimmed, type: nil, data: nil)
        }
        if pasteboard.availableType(from: [.URL]) != nil || isWebLink(trimmed) {
            return Content(kind: .url, text: trimmed, type: nil, data: nil)
        }
        if let format = pasteboard.availableType(from: richTextTypes) {
            return Content(
                kind: .richText, text: string, type: format, data: pasteboard.data(forType: format))
        }
        return Content(kind: .text, text: string, type: nil, data: nil)
    }
}
