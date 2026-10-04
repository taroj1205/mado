import AppKit
import ImageIO

@MainActor
final class Thumbnails {
    final class Request: NSObject, Sendable {
        let url: URL
        let side: Int

        override var hash: Int {
            var hasher = Hasher()
            hasher.combine(url)
            hasher.combine(side)
            return hasher.finalize()
        }

        init(url: URL, side: Int) {
            self.url = url
            self.side = side
        }

        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? Request else { return false }
            return other.url == url && other.side == side
        }
    }

    static let shared = Thumbnails()
    private static let limit = 500
    nonisolated private static let widest = 4

    private let cache = NSCache<Request, CGImage>()

    init() {
        cache.countLimit = Self.limit
    }

    nonisolated static func decode(_ request: Request) -> CGImage? {
        let uncached = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(request.url as CFURL, uncached),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
                as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int,
            min(width, height) > 0
        else { return nil }
        let short = min(width, height)
        let long = min(max(width, height), short * widest)
        let options =
            [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: (request.side * long + short - 1) / short,
            ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }

    func removeAll() {
        cache.removeAllObjects()
    }

    func cached(_ request: Request) -> CGImage? {
        cache.object(forKey: request)
    }

    func load(_ request: Request) async -> CGImage? {
        if let image = cached(request) {
            return image
        }
        guard !Task.isCancelled else { return nil }
        let image = await Task.detached(priority: .userInitiated) { Self.decode(request) }.value
        if let image, !Task.isCancelled {
            cache.setObject(image, forKey: request)
        }
        return image
    }
}
