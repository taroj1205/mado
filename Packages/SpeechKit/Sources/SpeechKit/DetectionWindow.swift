public struct DetectionWindow: Sendable {
    private static let frameSeconds = 0.02
    private static let speechFloorPower: Float = 1e-4
    private static let onsetFrames = 10
    private static let loudFramesAtOnset = 3
    private static let lengthSeconds = 3.0

    private static let frame = Int(Transcriber.sampleRate * frameSeconds)
    private static let length = Int(Transcriber.sampleRate * lengthSeconds)

    private var scanned = 0
    private var start: Int?

    public init() {
        scanned = 0
        start = nil
    }

    private static func isLoud(_ samples: [Float], at offset: Int) -> Bool {
        samples[offset..<offset + frame].reduce(0) { $0 + $1 * $1 } / Float(frame)
            > speechFloorPower
    }

    private static func speechStarts(in samples: [Float], at offset: Int) -> Bool {
        guard isLoud(samples, at: offset) else { return false }
        let loud = (0..<onsetFrames).count { isLoud(samples, at: offset + $0 * frame) }
        return loud >= loudFramesAtOnset
    }

    public mutating func range(in samples: [Float]) -> Range<Int>? {
        while start == nil, scanned + Self.onsetFrames * Self.frame <= samples.count {
            if Self.speechStarts(in: samples, at: scanned) { start = scanned }
            scanned += Self.frame
        }
        guard let start, samples.count >= start + Self.length else { return nil }
        return start..<start + Self.length
    }
}
