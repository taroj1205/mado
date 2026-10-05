extension ResultList {
    public struct Notice: Sendable, Equatable {
        public let title: String
        public let detail: String

        public init(title: String, detail: String) {
            self.title = title
            self.detail = detail
        }
    }
}
