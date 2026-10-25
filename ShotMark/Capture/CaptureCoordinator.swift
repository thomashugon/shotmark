import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Drives the capture flows and decides what happens with the resulting image.
@MainActor
final class CaptureCoordinator {
    static let shared = CaptureCoordinator()

    private var overlays: [SelectionOverlayController] = []
    private var editorWindows: [NSWindow] = []
    private var lastRegion: (displayID: CGDirectDisplayID, rect: CGRect)?

    // MARK: Capture flows

    func captureRegion() {
        guard overlays.isEmpty else { return }
        Task {
            await waitForMenuToClose()
            do {
                let snapshots = try await ScreenCapturer.snapshotAllScreens()
                showOverlays(for: snapshots)
            } catch {
                report(error)
            }
        }
    }

    func captureFullScreen() {
        Task {
            await waitForMenuToClose()
            guard let screen = NSScreen.underMouse else { return }
            do {
                let snapshot = try await ScreenCapturer.snapshot(of: screen)
                deliver(snapshot.image, scale: snapshot.scale)
            } catch {
                report(error)
            }
        }
    }

    func repeatLastRegion() {
        guard let last = lastRegion else {
            captureRegion()
            return
        }
        Task {
            await waitForMenuToClose()
            guard let screen = NSScreen.screens.first(where: { $0.displayID == last.displayID }) else { return }
            do {
                let snapshot = try await ScreenCapturer.snapshot(of: screen)
                if let image = snapshot.crop(last.rect) {
                    deliver(image, scale: snapshot.scale)
                }
            } catch {
                report(error)
            }
        }
    }

    func openImageInEditor() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return }
        openEditor(with: image, scale: 1)
    }

    // MARK: Region selection

    private func showOverlays(for snapshots: [ScreenSnapshot]) {
        let mouseScreen = NSScreen.underMouse
        overlays = snapshots.map { snapshot in
            SelectionOverlayController(snapshot: snapshot) { [weak self] snapshot, rect in
                self?.finishSelection(snapshot: snapshot, rect: rect)
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        for overlay in overlays {
            overlay.show(makeKey: overlay.snapshot.screen == mouseScreen)
        }
    }

    private func finishSelection(snapshot: ScreenSnapshot, rect: CGRect?) {
        overlays.forEach { $0.close() }
        overlays.removeAll()
        NSCursor.arrow.set()
        guard let rect, let image = snapshot.crop(rect) else { return }
        lastRegion = (snapshot.displayID, rect)
        deliver(image, scale: snapshot.scale)
    }

    // MARK: Output

    private func deliver(_ image: CGImage, scale: CGFloat) {
        switch AppSettings.afterCapture {
        case .openEditor:
            openEditor(with: image, scale: scale)
        case .copyToClipboard:
            ImageExporter.copyToClipboard(image)
        case .saveToFolder:
            do {
                _ = try ImageExporter.quickSave(image)
            } catch {
                report(error)
            }
        }
    }

    private func openEditor(with image: CGImage, scale: CGFloat) {
        let model = EditorModel(image: image, scale: scale)
        let window = NSWindow(contentViewController: NSHostingController(rootView: EditorView(model: model)))
        window.title = "ShotMark — \(image.width) × \(image.height)"
        window.styleMask.insert([.resizable, .closable, .miniaturizable])
        window.isReleasedWhenClosed = false
        let screenSize = (NSScreen.underMouse?.visibleFrame.size ?? CGSize(width: 1200, height: 800))
        window.setContentSize(CGSize(width: min(max(model.size.width + 40, 640), screenSize.width * 0.9),
                                     height: min(max(model.size.height + 100, 420), screenSize.height * 0.9)))
        window.center()
        editorWindows.append(window)
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification,
                                               object: window, queue: .main) { [weak self] note in
            MainActor.assumeIsolated {
                self?.editorWindows.removeAll { $0 === note.object as? NSWindow }
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: Helpers

    /// Lets the menu bar menu disappear before the screen is grabbed.
    private func waitForMenuToClose() async {
        try? await Task.sleep(for: .milliseconds(150))
    }

    private func report(_ error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "La capture a échoué"
        alert.informativeText = error.localizedDescription
            + "\n\nVérifiez que ShotMark est autorisé dans Réglages Système › Confidentialité et sécurité › Enregistrement de l'écran."
        alert.addButton(withTitle: "Ouvrir les réglages")
        alert.addButton(withTitle: "OK")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
