import AppKit
import SwiftUI

/// Small floating message near the top of the screen, dismissed automatically.
@MainActor
enum Toast {
    private static var panel: NSPanel?

    static func show(_ message: String, systemImage: String = "checkmark.circle.fill") {
        panel?.close()
        let content = Label(message, systemImage: systemImage)
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .fixedSize()
        let hosting = NSHostingView(rootView: content)
        let size = hosting.fittingSize

        let panel = NSPanel(contentRect: CGRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.contentView = hosting
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        if let screen = NSScreen.underMouse {
            let frame = screen.visibleFrame
            panel.setFrameOrigin(CGPoint(x: frame.midX - size.width / 2, y: frame.maxY - size.height - 24))
        }
        panel.orderFrontRegardless()
        self.panel = panel

        Task {
            try? await Task.sleep(for: .seconds(2))
            if self.panel === panel {
                panel.close()
                self.panel = nil
            }
        }
    }
}
