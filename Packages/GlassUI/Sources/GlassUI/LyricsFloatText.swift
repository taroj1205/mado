import Foundation

struct LyricsFloatText: Equatable {
    static let gap = "•  •  •"
    static let breakLabel = "Instrumental break"

    let heading: String
    let lines: [String]
    let current: Int?
    let spoken: String

    var line: String? {
        current.map { lines[$0] }
    }

    var previous: String? {
        current.flatMap { lines.indices.contains($0 - 1) ? lines[$0 - 1] : nil }
    }

    var next: String? {
        current.flatMap { lines.indices.contains($0 + 1) ? lines[$0 + 1] : nil }
    }

    init(_ verse: WidgetGrid.Verse) {
        heading = verse.artist.isEmpty ? verse.title : "\(verse.title) · \(verse.artist)"
        lines = verse.lines.map { $0.isEmpty ? Self.gap : $0 }
        let synced = verse.status == .synced ? verse.current : nil
        current = synced.flatMap { verse.lines.indices.contains($0) ? $0 : nil }
        let sung = current.map { verse.lines[$0] }
        let fallback = current == nil ? heading : Self.breakLabel
        spoken = sung.flatMap { $0.isEmpty ? nil : $0 } ?? fallback
    }

    func lyric(of verse: WidgetGrid.Verse) -> WidgetGrid.Lyric {
        guard let line else { return WidgetGrid.Lyric(text: heading, progress: 0, remaining: nil) }
        return WidgetGrid.Lyric(text: line, progress: verse.progress, remaining: verse.remaining)
    }
}
