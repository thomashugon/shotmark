import Foundation

enum AfterCaptureAction: String, CaseIterable, Identifiable {
    case openEditor, copyToClipboard, saveToFolder

    var id: String { rawValue }

    var label: String {
        switch self {
        case .openEditor: return "Ouvrir dans l'éditeur"
        case .copyToClipboard: return "Copier dans le presse-papiers"
        case .saveToFolder: return "Enregistrer dans le dossier"
        }
    }
}

enum ImageFormat: String, CaseIterable, Identifiable {
    case png, jpeg

    var id: String { rawValue }
    var fileExtension: String { self == .png ? "png" : "jpg" }
    var label: String { self == .png ? "PNG" : "JPEG" }
}

enum SettingsKey {
    static let afterCapture = "afterCapture"
    static let imageFormat = "imageFormat"
    static let saveFolder = "saveFolder"
    static let showCursor = "showCursor"
}

enum AppSettings {
    static var afterCapture: AfterCaptureAction {
        UserDefaults.standard.string(forKey: SettingsKey.afterCapture)
            .flatMap(AfterCaptureAction.init(rawValue:)) ?? .openEditor
    }

    static var imageFormat: ImageFormat {
        UserDefaults.standard.string(forKey: SettingsKey.imageFormat)
            .flatMap(ImageFormat.init(rawValue:)) ?? .png
    }

    static var defaultSaveFolderPath: String {
        FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.path
            ?? NSHomeDirectory()
    }

    static var saveFolder: URL {
        let path = UserDefaults.standard.string(forKey: SettingsKey.saveFolder) ?? defaultSaveFolderPath
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    static func fileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'à' HH.mm.ss"
        return "Capture \(formatter.string(from: date))"
    }
}
