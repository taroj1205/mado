import CoreGraphics
import CoreML
import Foundation
import Testing
import Vision

@testable import ClipboardKit

@Suite struct VisionProbeTests {
    private static func say(_ line: String) {
        FileHandle.standardError.write(Data("VISIONPROBE \(line)\n".utf8))
    }

    private static func run(
        _ label: String, _ image: CGImage, _ setup: (VNRecognizeTextRequest) throws -> Void
    ) {
        let request = VNRecognizeTextRequest()
        do {
            try setup(request)
            try VNImageRequestHandler(cgImage: image).perform([request])
            let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            say(
                "\(label) rev=\(request.revision) results=\(request.results?.count ?? -1) text=\(lines)"
            )
        } catch {
            say("\(label) error=\(error)")
        }
    }

    @Test func probe() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "probe-\(UUID()).png")
        defer { try? FileManager.default.removeItem(at: file) }
        try ImageTextTests.png(
            width: 1_440, height: 900,
            lines: ["Boarding pass", "Flight NZ 99 Gate 16", "Booking ref QX7K2M", "東京駅で待ち合わせ"]
        ).write(to: file)
        let image = try #require(ImageText.image(at: file))
        let request = VNRecognizeTextRequest()
        Self.say("langs=\((try? request.supportedRecognitionLanguages()) ?? [])")
        Self.say("devices=\((try? request.supportedComputeStageDevices) ?? [:])")
        Self.say(
            "os=\(ProcessInfo.processInfo.operatingSystemVersionString) model=\(ProcessInfo.processInfo.hostName)"
        )
        Self.run("accurate-ja-en", image) {
            $0.recognitionLevel = .accurate
            $0.recognitionLanguages = ["ja-JP", "en-US"]
        }
        Self.run("accurate-en", image) {
            $0.recognitionLevel = .accurate
            $0.recognitionLanguages = ["en-US"]
        }
        Self.run("fast-en", image) {
            $0.recognitionLevel = .fast
        }
        Self.run("accurate-cpu", image) { request in
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["ja-JP", "en-US"]
            for (stage, devices) in try request.supportedComputeStageDevices {
                if let cpu = devices.first(where: { if case .cpu = $0 { true } else { false } }) {
                    request.setComputeDevice(cpu, for: stage)
                }
            }
        }
    }
}
