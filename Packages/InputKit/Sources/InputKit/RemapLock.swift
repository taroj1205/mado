import Foundation

struct RemapLock {
    @MainActor private static var handedOver: [URL: Self] = [:]

    let url: URL
    let handle: FileHandle

    init?(url: URL) {
        let descriptor = unsafe open(
            url.path(percentEncoded: false), O_RDWR | O_CREAT | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { return nil }
        self.url = url
        handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    }

    @MainActor
    static func claim(_ url: URL) -> Self? {
        handedOver.removeValue(forKey: url) ?? Self(url: url)
    }

    func acquire() -> Bool {
        flock(handle.fileDescriptor, LOCK_EX | LOCK_NB) == 0
    }

    func release() {
        flock(handle.fileDescriptor, LOCK_UN)
    }

    @MainActor
    func handOver() {
        Self.handedOver[url] = self
        Task { @MainActor in
            guard Self.handedOver[url]?.handle === handle else { return }
            Self.handedOver[url] = nil
            release()
        }
    }
}
