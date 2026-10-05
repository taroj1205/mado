import Foundation
import os
import Testing

@testable import AppCore

@Suite struct SpeechModelStoreTests {
    private let root = FileManager.default.temporaryDirectory.appending(
        path: "SpeechModelStoreTests-\(UUID().uuidString)")
    private let contents = Data("not really a model".utf8)

    private var store: SpeechModelStore {
        SpeechModelStore(directory: root.appending(path: "Models"))
    }

    private func source() throws -> URL {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appending(path: "source.bin")
        try contents.write(to: file)
        return file
    }

    private func model(sha256: String) -> SpeechModel {
        SpeechModel(
            id: "test", name: "Test", file: "ggml-test.bin", size: Int64(contents.count),
            sha256: sha256, speed: .low, accuracy: .low, languages: 1, note: nil)
    }

    private func install(_ model: SpeechModel) throws {
        try FileManager.default.createDirectory(
            at: store.directory, withIntermediateDirectories: true)
        try Data().write(to: store.location(of: model))
    }

    private func download(_ model: SpeechModel, from url: URL) async throws -> [Double] {
        let steps = OSAllocatedUnfairLock(initialState: [Double]())
        try await store.download(model, from: url) { step in steps.withLock { $0.append(step) } }
        return steps.withLock { $0 }
    }

    @Test func aDownloadMatchingItsHashIsInstalled() async throws {
        let model = model(
            sha256: "29a6a9f19463c8e9c592d2f06fa009fe46e351b618667e95eac63df77c56f404")
        #expect(try await download(model, from: source()) == [1])
        #expect(store.isInstalled(model))
        #expect(try Data(contentsOf: store.location(of: model)) == contents)
        try store.delete(model)
        #expect(!store.isInstalled(model))
    }

    @Test func aDownloadWithAnotherHashIsNotInstalled() async throws {
        let model = model(sha256: String(repeating: "0", count: 64))
        await #expect(throws: SpeechModelStore.Failure.corrupt) {
            try await download(model, from: source())
        }
        #expect(!store.isInstalled(model))
    }

    @Test func aMissingSourceIsNotInstalled() async throws {
        let model = model(sha256: "")
        await #expect(throws: (any Error).self) {
            try await download(model, from: root.appending(path: "missing.bin"))
        }
        #expect(!store.isInstalled(model))
    }

    @Test func thePreferredModelIsUsedWhileInstalled() throws {
        let small = SpeechModel.all[0]
        let turbo = SpeechModel.all[2]
        #expect(store.model(preferring: turbo.id) == nil)
        try install(small)
        #expect(store.model(preferring: turbo.id) == small)
        #expect(store.model(preferring: nil) == small)
        try install(turbo)
        #expect(store.model(preferring: turbo.id) == turbo)
        try store.delete(turbo)
        #expect(store.model(preferring: turbo.id) == small)
    }

    @Test func everyModelIsPinnedToARevision() throws {
        for model in SpeechModel.all {
            let url = try #require(model.url)
            #expect(url.host() == "huggingface.co")
            #expect(url.lastPathComponent == model.file)
            #expect(url.pathComponents.contains("5359861c739e955e79d9a303bcbc70fb988958b1"))
        }
        #expect(Set(SpeechModel.all.map(\.id)).count == SpeechModel.all.count)
    }
}
