public struct DetectionWindow: Sendable {
    private static let frameSeconds = 0.02
    private static let speechFloorPower: Float = 1e-4
    private static let lengthSeconds = 3.0

    private static let frame = Int(Transcriber.sampleRate * frameSeconds)
    private static let length = Int(Transcriber.sampleRate * lengthSeconds)

    private var scanned = 0
    private var start: Int?

    public init() {
        scanned = 0
        start = nil
    }

    public mutating func range(in samples: [Float]) -> Range<Int>? {
        while start == nil, scanned + Self.frame <= samples.count {
            let power =
                samples[scanned..<scanned + Self.frame].reduce(0) { $0 + $1 * $1 }
                / Float(Self.frame)
            if power > Self.speechFloorPower { start = scanned }
            scanned += Self.frame
        }
        guard let start, samples.count >= start + Self.length else { return nil }
        return start..<start + Self.length
    }
}
