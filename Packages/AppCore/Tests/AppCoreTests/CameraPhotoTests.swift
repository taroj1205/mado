import AppKit
import Foundation
import Testing

@testable import AppCore

@Suite struct CameraPhotoTests {
    private let moment = Date(timeIntervalSince1970: 1_760_000_000)
    private let jpeg: Data = {
        let bitmap = unsafe NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 4, bitsPerSample: 8,
            samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0)
        return bitmap?.representation(using: .jpeg, properties: [:]) ?? Data()
    }()

    private func temporaryFolder() -> URL {
        FileManager.default.temporaryDirectory.appending(
            path: "mado-camera-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    @Test func createsTheFolderAndWritesTheJPEGUnderTheTime() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = try CameraPhoto.save(jpeg, in: folder, at: moment)
        #expect(url.deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL)
        #expect(url.pathExtension == "jpg")
        #expect(url.lastPathComponent.hasPrefix("Mado Camera "))
        #expect(try Data(contentsOf: url) == jpeg)
    }

    @Test func keepsBothPhotosTakenInTheSameSecond() throws {
        let folder = temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let first = try CameraPhoto.save(jpeg, in: folder, at: moment)
        let second = try CameraPhoto.save(Data([1]), in: folder, at: moment)
        let third = try CameraPhoto.save(Data([2]), in: folder, at: moment)
        #expect(
            second.lastPathComponent == first.deletingPathExtension().lastPathComponent + " 2.jpg")
        #expect(
            third.lastPathComponent == first.deletingPathExtension().lastPathComponent + " 3.jpg")
        #expect(try Data(contentsOf: first) == jpeg)
        #expect(try Data(contentsOf: second) == Data([1]))
    }

    @Test func copiesThePhotoAsAnImage() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        #expect(CameraPhoto.copy(jpeg, to: pasteboard))
        let images = pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage]
        #expect(images?.count == 1)
    }

    @Test func leavesTheClipboardAloneWhenThePhotoCannotBeRead() {
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.setString("kept", forType: .string)
        #expect(!CameraPhoto.copy(Data([0]), to: pasteboard))
        #expect(pasteboard.string(forType: .string) == "kept")
    }

    @Test func savesUnderPicturesInAFolderOfItsOwn() {
        #expect(CameraPhoto.folder.lastPathComponent == "Mado")
        #expect(CameraPhoto.folder.deletingLastPathComponent().lastPathComponent == "Pictures")
    }
}
