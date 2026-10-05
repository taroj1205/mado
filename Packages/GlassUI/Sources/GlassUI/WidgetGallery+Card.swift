import Foundation

extension WidgetGallery {
    public enum Group: CaseIterable, Sendable {
        case today
        case system
        case media
        case text

        var title: String {
            switch self {
            case .today: "Today"
            case .system: "System"
            case .media: "Media"
            case .text: "Text"
            }
        }
    }

    public struct Card: Equatable, Sendable {
        public let id: String
        public let name: String
        public let summary: String
        public let group: Group
        public let isWide: Bool

        public var placeholder: WidgetGrid.Widget {
            .init(
                id: id, name: name, content: .unavailable(title: name, summary: summary),
                action: "", spoken: "\(name): \(summary)", isWide: isWide)
        }

        public init(id: String, name: String, summary: String, group: Group, isWide: Bool = false) {
            self.id = id
            self.name = name
            self.summary = summary
            self.group = group
            self.isWide = isWide
        }

        func matches(_ words: String) -> Bool {
            words.isEmpty
                || [name, summary, group.title].contains { text in
                    text.localizedCaseInsensitiveContains(words)
                }
        }
    }
}
