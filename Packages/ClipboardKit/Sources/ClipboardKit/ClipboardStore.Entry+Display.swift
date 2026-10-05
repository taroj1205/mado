import AppCore
public import AppKit
import ImageIO

extension ClipboardStore.Entry {
    public typealias Detail = (name: String, value: String)

    public struct RGB: Equatable, Sendable {
        public let red: Int
        public let green: Int
        public let blue: Int

        var components: String {
            "\(red), \(green), \(blue)"
        }
    }

    public struct Counts: Equatable, Sendable {
        public let characters: Int
        public let words: Int

        init(characters: Int, words: Int) {
            self.characters = characters
            self.words = words
        }

        init(of text: String, until stopping: @escaping () -> Bool) {
            var count = 0
            text.enumerateSubstrings(
                in: text.startIndex..., options: [.byWords, .substringNotRequired]
            ) { _, _, _, stop in
                count += 1
                stop = stopping()
            }
            self.init(characters: text.count, words: count)
        }
    }

    private static let quickCount = 100_000
    private static let counting = "…"
    private static let hexDigits = 6
    private static let hexRadix = 16
    private static let byte = 0xFF
    private static let redShift = 16
    private static let greenShift = 8

    public var title: String {
        Clip.title(kind, text: text, files: files)
    }

    public var preview: String {
        switch kind {
        case .image: ""
        case .color: rgb.map { "\(text)\nrgb(\($0.components))" } ?? text
        case .text, .richText, .url, .file: text
        }
    }

    public var rgb: RGB? {
        let digits = text.dropFirst().prefix(Self.hexDigits)
        guard kind == .color, text.first == "#", digits.count == Self.hexDigits,
            let value = Int(digits, radix: Self.hexRadix)
        else { return nil }
        return RGB(
            red: value >> Self.redShift & Self.byte, green: value >> Self.greenShift & Self.byte,
            blue: value & Self.byte)
    }

    public var plainText: String? {
        kind == .image ? nil : text
    }

    public var counts: Counts {
        count { false }
    }

    public var quickCounts: Counts? {
        text.utf16.count <= Self.quickCount ? counts : nil
    }

    private var imageDetails: [Detail] {
        guard let image else { return [] }
        let size = (try? image.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
        let details: [Detail?] = [
            Self.dimensions(of: image).map { ("Dimensions", $0) },
            size.map { bytes in
                ("Size", ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file))
            },
        ]
        return details.compactMap(\.self)
    }

    private static func dimensions(of image: URL) -> String? {
        guard let source = CGImageSourceCreateWithURL(image as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return "\(width) × \(height)"
    }

    public static func byDay(
        _ entries: [Self], calendar: Calendar
    ) -> [(day: Date, entries: [Self])] {
        var days: [(day: Date, entries: [Self])] = []
        for entry in entries {
            let day = calendar.startOfDay(for: entry.date)
            if days.last?.day == day {
                days[days.count - 1].entries.append(entry)
            } else {
                days.append((day, [entry]))
            }
        }
        return days
    }

    @concurrent
    public func backgroundCounts() async -> Counts? {
        let counted = count { Task.isCancelled }
        return Task.isCancelled ? nil : counted
    }

    func count(until stopping: @escaping () -> Bool) -> Counts {
        Counts(of: text, until: stopping)
    }

    private func kindDetails(_ counts: Counts?) -> [Detail] {
        let characters = ("Characters", counts?.characters.formatted() ?? Self.counting)
        switch kind {
        case .text, .richText:
            return [characters, ("Words", counts?.words.formatted() ?? Self.counting)]

        case .url:
            let host = URL(string: text)?.host().map { [("Host", $0)] } ?? []
            return [characters] + host

        case .color:
            guard let rgb else { return [] }
            return [("Hex", text), ("RGB", rgb.components)]

        case .image:
            return imageDetails

        case .file:
            return [("Files", files.count.formatted())]
        }
    }

    public func details(
        source: String, now: Date, calendar: Calendar, counts: Counts?
    ) -> [Detail] {
        let day = RelativeDay.title(of: date, now: now, calendar: calendar)
        let copied = "\(day) at \(date.formatted(date: .omitted, time: .shortened))"
        return [("Source", source), ("Content type", kind.title)] + kindDetails(counts)
            + [("Copied", copied)]
    }

    @MainActor
    public func copy(data: Data?, to pasteboard: NSPasteboard = .general) throws {
        try PasteTarget.write(pasteboardItems(data: data), to: pasteboard)
    }

    @MainActor
    public func paste(data: Data?, into target: PasteTarget) async throws {
        try await target.paste(pasteboardItems(data: data))
    }

    @MainActor
    public func pastePlainText(into target: PasteTarget) async throws {
        try await target.paste(plainTextItems())
    }

    @MainActor
    func plainTextItems() throws -> [NSPasteboardItem] {
        guard let plainText else { throw PasteTarget.Failure.notWritten }
        let item = NSPasteboardItem()
        item.setString(plainText, forType: .string)
        item.setData(Data(), forType: PasteboardWatch.transientType)
        return [item]
    }

    @MainActor
    func pasteboardItems(data: Data?) throws -> [NSPasteboardItem] {
        let content = kind == .image ? try image.map { try Data(contentsOf: $0) } : data
        return try Clip.pasteboardItems(kind, text: text, type: type, data: content, files: files)
    }
}
