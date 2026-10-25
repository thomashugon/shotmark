import SwiftUI

@main
struct ShotMarkApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("ShotMark", systemImage: "camera.viewfinder") {
            MenuContent()
        }
        Settings {
            SettingsView()
        }
    }
}

private struct MenuContent: View {
    var body: some View {
        Button("Capturer une zone ou une fenêtre  ⌥⇧4") {
            CaptureCoordinator.shared.captureRegion()
        }
        Button("Capturer l'écran entier  ⌥⇧3") {
            CaptureCoordinator.shared.captureFullScreen()
        }
        Button("Copier le texte d'une zone (OCR)  ⌥⇧2") {
            CaptureCoordinator.shared.captureText()
        }
        Button("Répéter la dernière zone  ⌥⇧5") {
            CaptureCoordinator.shared.repeatLastRegion()
        }
        Divider()
        Button("Ouvrir une image dans l'éditeur…") {
            CaptureCoordinator.shared.openImageInEditor()
        }
        Divider()
        SettingsLink {
            Text("Réglages…")
        }
        .keyboardShortcut(",")
        Button("Quitter ShotMark") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
