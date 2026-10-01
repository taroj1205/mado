import CoreServices
import Foundation

@safe
final class FolderWatcher {
    private final class Handler: Sendable {
        let onChange: @MainActor @Sendable () -> Void

        init(_ onChange: @escaping @MainActor @Sendable () -> Void) {
            self.onChange = onChange
        }
    }

    private let stream: FSEventStreamRef

    init?(
        folders: [URL], latency: TimeInterval,
        onChange: @escaping @MainActor @Sendable () -> Void
    ) {
        let handler = Handler(onChange)
        var context = unsafe FSEventStreamContext(
            version: 0,
            info: unsafe Unmanaged.passUnretained(handler).toOpaque(),
            retain: { info in
                guard let pointer = unsafe info else { return nil }
                _ = unsafe Unmanaged<Handler>.fromOpaque(pointer).retain()
                return unsafe pointer
            },
            release: { info in
                guard let pointer = unsafe info else { return }
                unsafe Unmanaged<Handler>.fromOpaque(pointer).release()
            },
            copyDescription: nil)
        guard
            let created = unsafe FSEventStreamCreate(
                nil,
                { _, info, _, _, _, _ in
                    guard let pointer = unsafe info else { return }
                    let notify = unsafe Unmanaged<Handler>.fromOpaque(pointer)
                        .takeUnretainedValue().onChange
                    MainActor.assumeIsolated { notify() }
                },
                &context, folders.map(\.path) as CFArray,
                FSEventStreamEventId(kFSEventStreamEventIdSinceNow), latency,
                FSEventStreamCreateFlags(kFSEventStreamCreateFlagNone))
        else { return nil }
        unsafe FSEventStreamSetDispatchQueue(created, .main)
        guard unsafe FSEventStreamStart(created) else {
            unsafe FSEventStreamInvalidate(created)
            unsafe FSEventStreamRelease(created)
            return nil
        }
        unsafe stream = created
    }

    deinit {
        unsafe FSEventStreamStop(stream)
        unsafe FSEventStreamInvalidate(stream)
        unsafe FSEventStreamRelease(stream)
    }
}
