import os

final class AbortFlag: Sendable {
    private let raised = OSAllocatedUnfairLock(initialState: false)

    var isRaised: Bool {
        raised.withLock { $0 }
    }

    func raise() {
        raised.withLock { $0 = true }
    }
}
