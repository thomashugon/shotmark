import AppKit
import UniformTypeIdentifiers

@MainActor
enum ImageExporter {
    static func copyToClipboard(_ image: CGImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([NSImage(cgImage: image, size: .zero)])
    }

    static func encode(_ image: CGImage, as format: ImageFormat) -> Data? {
        let rep = NSBitmapImageRep(cgImage: image)
        switch format {
        case .png: return rep.representation(using: .png, properties: [:])
        case .jpeg: return rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        }
    }

    /// Saves to the configured folder with a timestamped name, without asking.
    @discardableResult
    static func quickSave(_ image: CGImage) throws -> URL {
        let format = AppSettings.imageFormat
        let folder = AppSettings.saveFolder
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = uniqueURL(in: folder, baseName: AppSettings.fileName(for: Date()), ext: format.fileExtension)
        guard let data = encode(image, as: format) else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: url)
        return url
    }

    static func saveWithPanel(_ image: CGImage) -> URL? {
        let panel = NSSavePanel()
        let format = AppSettings.imageFormat
        panel.allowedContentTypes = [.png, .jpeg]
        panel.nameFieldStringValue = "\(AppSettings.fileName(for: Date())).\(format.fileExtension)"
        panel.directoryURL = AppSettings.saveFolder
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        let chosen: ImageFormat = url.pathExtension.lowercased().hasPrefix("jp") ? .jpeg : .png
        guard let data = encode(image, as: chosen) else { return nil }
        do {
            try data.write(to: url)
            return url
        } catch {
            NSAlert(error: error).runModal()
            return nil
        }
    }

    private static func uniqueURL(in folder: URL, baseName: String, ext: String) -> URL {
        var url = folder.appendingPathComponent(baseName).appendingPathExtension(ext)
        var index = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(baseName) (\(index))").appendingPathExtension(ext)
            index += 1
        }
        return url
    }
}
