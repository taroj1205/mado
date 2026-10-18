import AVFAudio
public import Foundation

public struct DictationLog: Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        let date: Date
        let model: String
        let languages: [String]
        let words: [String]
        let text: String

        public init(date: Date, model: String, languages: [String], words: [String], text: String) {
            self.date = date
            self.model = model
            self.languages = languages
            self.words = words
            self.text = text
        }
    }

    enum Failure: Error {
        case unwritable
    }

    public static let limit = 50

    private static let channels = 1
    private static let bitDepth = 16
    private static let audio = "wav"
    private static let metadata = "json"
    private static let extensions = [audio, metadata]

    public static let standard: Self = {
        #if DEBUG
            let name = "Dictations.debug"
        #else
            let name = "Dictations"
        #endif
        return Self(directory: .applicationSupportDirectory.appending(path: "Mado/\(name)"))
    }()

    public let directory: URL

    static func name(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .gmt
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return formatter.string(from: date)
    }

    static func write(_ samples: [Float], sampleRate: Double, to url: URL) throws {
        let file = try AVAudioFile(
            forWriting: url,
            settings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVLinearPCMBitDepthKey: bitDepth,
                AVLinearPCMIsFloatKey: false,
            ],
            commonFormat: .pcmFormatFloat32, interleaved: false)
        guard
            let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(samples.count)),
            let data = unsafe buffer.floatChannelData
        else { throw Failure.unwritable }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        unsafe data[0].update(from: samples, count: samples.count)
        try file.write(from: buffer)
    }

    @concurrent
    public func keep(_ samples: [Float], sampleRate: Double, as entry: Entry) async throws {
        var folder = directory
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try folder.setResourceValues(values)

        let name = Self.name(for: entry.date)
        let audioFile = folder.appending(path: "\(name).\(Self.audio)")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        do {
            try Self.write(samples, sampleRate: sampleRate, to: audioFile)
            try encoder.encode(entry).write(
                to: folder.appending(path: "\(name).\(Self.metadata)"), options: .atomic)
        } catch {
            try? FileManager.default.removeItem(at: audioFile)
            throw error
        }
        prune()
    }

    func entries() throws -> [Entry] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try stems(of: [Self.metadata]).map { name in
            try decoder.decode(
                Entry.self,
                from: Data(contentsOf: directory.appending(path: "\(name).\(Self.metadata)")))
        }
    }

    private func stems(of extensions: [String]) throws -> [String] {
        let files = try FileManager.default.contentsOfDirectory(
            atPath: directory.path(percentEncoded: false))
        return Set(
            files.compactMap { file in
                let url = URL(filePath: file)
                return extensions.contains(url.pathExtension)
                    ? url.deletingPathExtension().lastPathComponent : nil
            }
        ).sorted()
    }

    private func prune() {
        for name in ((try? stems(of: Self.extensions)) ?? []).dropLast(Self.limit) {
            for ext in Self.extensions {
                try? FileManager.default.removeItem(at: directory.appending(path: "\(name).\(ext)"))
            }
        }
    }
}
