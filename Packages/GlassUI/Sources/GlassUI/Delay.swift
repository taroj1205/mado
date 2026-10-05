@MainActor
final class Delay {
    var duration: Duration
    private var task: Task<Void, Never>?

    init(seconds: Double) {
        duration = .seconds(seconds)
    }

    func start(_ action: @escaping @MainActor () -> Void) {
        cancel()
        task = Task { [duration] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            action()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
