import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let modifiers = UInt32(optionKey | shiftKey)
        let hotKeys = HotKeyManager.shared
        hotKeys.register(keyCode: UInt32(kVK_ANSI_4), modifiers: modifiers) {
            CaptureCoordinator.shared.captureRegion()
        }
        hotKeys.register(keyCode: UInt32(kVK_ANSI_3), modifiers: modifiers) {
            CaptureCoordinator.shared.captureFullScreen()
        }
        hotKeys.register(keyCode: UInt32(kVK_ANSI_2), modifiers: modifiers) {
            CaptureCoordinator.shared.captureText()
        }
        hotKeys.register(keyCode: UInt32(kVK_ANSI_5), modifiers: modifiers) {
            CaptureCoordinator.shared.repeatLastRegion()
        }
    }
}
