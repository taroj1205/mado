import CoreGraphics
import CoreML
import Foundation
import Testing
import Vision

@testable import ClipboardKit

@Suite struct VisionProbeTests {
    private static func image() throws -> CGImage {
        let file = FileManager.default.temporaryDirectory.appending(path: "probe-\(UUID()).png")
        defer { try? FileManager.default.removeItem(at: file) }
        try ImageTextTests.png(
            width: 1_440, height: 900,
            lines: ["Boarding pass", "Flight NZ 99 Gate 16", "Booking ref QX7K2M", "東京駅で待ち合わせ"]
        ).write(to: file)
        return try #require(ImageText.image(at: file))
    }

    private static func lines(_ setup: (VNRecognizeTextRequest) throws -> Void) throws -> [String] {
        let request = VNRecognizeTextRequest()
        try setup(request)
        try VNImageRequestHandler(cgImage: image()).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
    }

    private static func cpu(_ request: VNRecognizeTextRequest) throws {
        for (stage, devices) in try request.supportedComputeStageDevices {
            if let cpu = devices.first(where: { if case .cpu = $0 { true } else { false } }) {
                request.setComputeDevice(cpu, for: stage)
            }
        }
    }

    @Test func p01_accurateJaEnDoesNotThrow() throws {
        _ = try Self.lines { $0.recognitionLanguages = ["ja-JP", "en-US"] }
    }
    @Test func p02_accurateJaEnHasResults() throws {
        #expect(!(try Self.lines { $0.recognitionLanguages = ["ja-JP", "en-US"] }).isEmpty)
    }
    @Test func p03_accurateJaEnFindsCode() throws {
        #expect(try Self.lines { $0.recognitionLanguages = ["ja-JP", "en-US"] }.joined().contains("QX7K2M"))
    }
    @Test func p04_accurateJaEnFindsJapanese() throws {
        #expect(try Self.lines { $0.recognitionLanguages = ["ja-JP", "en-US"] }.joined().contains("待ち合わせ"))
    }
    @Test func p05_accurateEnFindsCode() throws {
        #expect(try Self.lines { $0.recognitionLanguages = ["en-US"] }.joined().contains("QX7K2M"))
    }
    @Test func p06_fastFindsCode() throws {
        #expect(try Self.lines { $0.recognitionLevel = .fast }.joined().contains("QX7K2M"))
    }
    @Test func p07_cpuAccurateJaEnFindsCode() throws {
        #expect(try Self.lines {
            $0.recognitionLanguages = ["ja-JP", "en-US"]
            try Self.cpu($0)
        }.joined().contains("QX7K2M"))
    }
    @Test func p08_jaSupported() throws {
        #expect(try VNRecognizeTextRequest().supportedRecognitionLanguages().contains("ja-JP"))
    }
    @Test func p09_hasNeuralEngine() throws {
        #expect(try VNRecognizeTextRequest().supportedComputeStageDevices.values.joined().contains {
            if case .neuralEngine = $0 { true } else { false }
        })
    }
    @Test func p10_hasGPU() throws {
        #expect(try VNRecognizeTextRequest().supportedComputeStageDevices.values.joined().contains {
            if case .gpu = $0 { true } else { false }
        })
    }
    @Test func p11_backgroundPreferenceFindsCode() throws {
        #expect(try Self.lines {
            $0.recognitionLanguages = ["ja-JP", "en-US"]
            $0.preferBackgroundProcessing = true
        }.joined().contains("QX7K2M"))
    }
    @Test func p12_storeRecognizeDirect() async throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "probe-\(UUID()).png")
        defer { try? FileManager.default.removeItem(at: file) }
        try ImageTextTests.png(width: 1_440, height: 900, lines: ["Booking ref QX7K2M"]).write(to: file)
        #expect(try await ImageText.recognize(at: file).contains("QX7K2M"))
    }
}
