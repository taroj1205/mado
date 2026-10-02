extension ResultList {
    public struct Word: Sendable, Equatable {
        public let title: String
        public let query: String

        public init(title: String, query: String) {
            self.title = title
            self.query = query
        }
    }

    public struct Card: Sendable, Equatable {
        public let title: String
        public let detail: String
        public let text: String
        public let similar: [Word]
        public let opposite: [String]

        public init(
            title: String, detail: String, text: String, similar: [Word], opposite: [String]
        ) {
            self.title = title
            self.detail = detail
            self.text = text
            self.similar = similar
            self.opposite = opposite
        }
    }
}
