import Foundation

struct RemapLock {
    let handle: FileHandle

    init?(url: URL) {
        let descriptor = unsafe open(
            url.path(percentEncoded: false), O_RDWR | O_CREAT | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { return nil }
        handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    }

    func acquire() -> Bool {
        flock(handle.fileDescriptor, LOCK_EX | LOCK_NB) == 0
    }

    func release() {
        flock(handle.fileDescriptor, LOCK_UN)
    }
}
