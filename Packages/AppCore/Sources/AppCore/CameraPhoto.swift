public import AppKit
import Foundation

public enum CameraPhoto {
    private static let folderName = "Mado"
    private static let namePrefix = "Mado Camera"
    private static let nameFormat = "yyyy-MM-dd 'at' HH.mm.ss"

    public static var folder: URL {
        FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask)[0]
            .appending(path: folderName, directoryHint: .isDirectory)
    }

    public static func save(_ data: Data, in folder: URL, at date: Date = .now) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = nameFormat
        let base = "\(namePrefix) \(formatter.string(from: date))"
        var attempt = 1
        while true {
            let name = attempt == 1 ? base : "\(base) \(attempt)"
            let url = folder.appending(path: "\(name).jpg")
            do {
                try data.write(to: url, options: .withoutOverwriting)
                return url
            } catch CocoaError.fileWriteFileExists {
                attempt += 1
            }
        }
    }

    @discardableResult
    public static func copy(_ data: Data, to pasteboard: NSPasteboard) -> Bool {
        guard let image = NSImage(data: data) else { return false }
        pasteboard.clearContents()
        return pasteboard.writeObjects([image])
    }
}
