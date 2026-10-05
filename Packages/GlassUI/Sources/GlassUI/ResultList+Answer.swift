extension ResultList {
    public struct Answer: Sendable, Equatable {
        public let value: String
        public let detail: String

        public init(value: String, detail: String) {
            self.value = value
            self.detail = detail
        }
    }
}
