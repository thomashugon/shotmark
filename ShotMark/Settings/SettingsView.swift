import AppKit
import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKey.afterCapture) private var afterCapture = AfterCaptureAction.openEditor
    @AppStorage(SettingsKey.imageFormat) private var imageFormat = ImageFormat.png
    @AppStorage(SettingsKey.saveFolder) private var saveFolder = AppSettings.defaultSaveFolderPath
    @AppStorage(SettingsKey.showCursor) private var showCursor = false

    var body: some View {
        Form {
            Picker("Après la capture", selection: $afterCapture) {
                ForEach(AfterCaptureAction.allCases) { Text($0.label).tag($0) }
            }
            Picker("Format", selection: $imageFormat) {
                ForEach(ImageFormat.allCases) { Text($0.label).tag($0) }
            }
            LabeledContent("Dossier") {
                HStack {
                    Text((saveFolder as NSString).abbreviatingWithTildeInPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button("Choisir…", action: chooseFolder)
                }
            }
            Toggle("Inclure le pointeur de la souris", isOn: $showCursor)

            Section("Raccourcis") {
                LabeledContent("Zone ou fenêtre", value: "⌥⇧4")
                LabeledContent("Écran entier", value: "⌥⇧3")
                LabeledContent("Copier le texte (OCR)", value: "⌥⇧2")
                LabeledContent("Répéter la dernière zone", value: "⌥⇧5")
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding()
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: saveFolder)
        if panel.runModal() == .OK, let url = panel.url {
            saveFolder = url.path
        }
    }
}
