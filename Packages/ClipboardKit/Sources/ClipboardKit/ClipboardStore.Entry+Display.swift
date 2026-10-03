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

    private static let titleLimit = 200
    private static let hexDigits = 6
    private static let hexRadix = 16
    private static let byte = 0xFF
    private static let redShift = 16
    private static let greenShift = 8

    public var title: String {
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
            return String(line.prefix(Self.titleLimit))
        }
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

    private var words: Int {
        var count = 0
        text.enumerateSubstrings(
            in: text.startIndex..., options: [.byWords, .substringNotRequired]
        ) { _, _, _, _ in count += 1 }
        return count
    }

    private var kindDetails: [Detail] {
        switch kind {
        case .text, .richText:
            return [("Characters", text.count.formatted()), ("Words", words.formatted())]

        case .url:
            let host = URL(string: text)?.host().map { [("Host", $0)] } ?? []
            return [("Characters", text.count.formatted())] + host

        case .color:
            guard let rgb else { return [] }
            return [("Hex", text), ("RGB", rgb.components)]

        case .image:
            return imageDetails

        case .file:
            return [("Files", files.count.formatted())]
        }
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

    public func details(source: String, now: Date, calendar: Calendar) -> [Detail] {
        let day = RelativeDay.title(of: date, now: now, calendar: calendar)
        let copied = "\(day) at \(date.formatted(date: .omitted, time: .shortened))"
        return [("Source", source), ("Content type", kind.title)] + kindDetails
            + [("Copied", copied)]
    }

    @MainActor
    public func copy(data: Data?, to pasteboard: NSPasteboard = .general) throws {
        try PasteTarget.write(pasteboardItems(data: data), to: pasteboard)
    }

    @MainActor
    func pasteboardItems(data: Data?) throws -> [NSPasteboardItem] {
        let items: [NSPasteboardItem]
        switch kind {
        case .file:
            items = files.map { file in
                let item = NSPasteboardItem()
                item.setString(file.absoluteString, forType: .fileURL)
                return item
            }

        case .image:
            guard let image, let type else { throw PasteTarget.Failure.notWritten }
            let item = NSPasteboardItem()
            item.setData(try Data(contentsOf: image), forType: .init(type))
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
}
