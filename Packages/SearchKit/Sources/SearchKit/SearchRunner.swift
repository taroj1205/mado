@MainActor
public final class SearchRunner<Results> {
    private let search: @MainActor (String) async -> Results
    private let deliver: @MainActor (Results) -> Void
    private(set) var task: Task<Void, Never>?

    public init(
        search: @escaping @MainActor (String) async -> Results,
        deliver: @escaping @MainActor (Results) -> Void
    ) {
        self.search = search
        self.deliver = deliver
    }

    public func run(_ query: String) {
        task?.cancel()
        task = Task {
            guard !Task.isCancelled else { return }
            let results = await search(query)
            guard !Task.isCancelled else { return }
            deliver(results)
        }
    }
}
