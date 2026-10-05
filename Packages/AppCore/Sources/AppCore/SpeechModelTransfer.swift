import Foundation
import os

final class SpeechModelTransfer: NSObject, URLSessionDownloadDelegate, Sendable {
    private struct State {
        var continuation: CheckedContinuation<URL, any Error>?
        var percent = -1
    }

    private static let percent = 100.0
    private static let success = 200

    private let size: Int64
    private let progress: @Sendable (Double) -> Void
    private let state = OSAllocatedUnfairLock(initialState: State())

    init(size: Int64, progress: @escaping @Sendable (Double) -> Void) {
        self.size = size
        self.progress = progress
    }

    func start(_ task: URLSessionDownloadTask) async throws -> URL {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                state.withLock { $0.continuation = continuation }
                task.resume()
            }
        } onCancel: {
            task.cancel()
        }
    }

    func urlSession(
        _: URLSession, downloadTask _: URLSessionDownloadTask, didWriteData _: Int64,
        totalBytesWritten written: Int64, totalBytesExpectedToWrite _: Int64
    ) {
        let fraction = min(Double(written) / Double(size), 1)
        let step = Int(fraction * Self.percent)
        let changed = state.withLock { state in
            defer { state.percent = step }
            return state.percent != step
        }
        if changed {
            progress(fraction)
        }
    }

    func urlSession(
        _: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL
    ) {
        finish {
            let status = (downloadTask.response as? HTTPURLResponse)?.statusCode
            guard status == nil || status == Self.success else {
                throw SpeechModelStore.Failure.badResponse
            }
            let kept = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            try FileManager.default.moveItem(at: location, to: kept)
            return kept
        }
    }

    func urlSession(
        _: URLSession, task _: URLSessionTask, didCompleteWithError error: (any Error)?
    ) {
        if let error {
            finish { throw error }
        }
    }

    private func finish(_ result: () throws -> URL) {
        guard let continuation = state.withLock({ $0.continuation.take() }) else { return }
        continuation.resume(with: Result(catching: result))
    }
}
