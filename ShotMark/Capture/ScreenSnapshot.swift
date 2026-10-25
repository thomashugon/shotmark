import AppKit
import ScreenCaptureKit

/// A frozen image of one display, plus the on-screen windows it contains.
/// All rects are in points, top-left origin, relative to the display.
struct ScreenSnapshot {
    let image: CGImage
    let screen: NSScreen
    let displayID: CGDirectDisplayID
    /// Display bounds in global Quartz coordinates (top-left origin).
    let displayBounds: CGRect
    /// Visible windows, front to back.
    let windowFrames: [CGRect]

    var pointSize: CGSize { displayBounds.size }
    var scale: CGFloat { CGFloat(image.width) / displayBounds.width }

    /// Crops a rect expressed in display points.
    func crop(_ rect: CGRect) -> CGImage? {
        let bounds = CGRect(origin: .zero, size: pointSize)
        let clipped = rect.intersection(bounds)
        guard !clipped.isNull, clipped.width >= 1, clipped.height >= 1 else { return nil }
        let pixels = CGRect(x: clipped.minX * scale,
                            y: clipped.minY * scale,
                            width: clipped.width * scale,
                            height: clipped.height * scale).integral
        return image.cropping(to: pixels)
    }
}

enum CaptureError: LocalizedError {
    case displayNotFound

    var errorDescription: String? {
        switch self {
        case .displayNotFound: return "Écran introuvable."
        }
    }
}

@MainActor
enum ScreenCapturer {
    static func snapshotAllScreens() async throws -> [ScreenSnapshot] {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let windows = visibleWindowFrames()
        var snapshots: [ScreenSnapshot] = []
        for screen in NSScreen.screens {
            snapshots.append(try await snapshot(of: screen, content: content, windows: windows))
        }
        return snapshots
    }

    static func snapshot(of screen: NSScreen) async throws -> ScreenSnapshot {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        return try await snapshot(of: screen, content: content, windows: visibleWindowFrames())
    }

    private static func snapshot(of screen: NSScreen,
                                 content: SCShareableContent,
                                 windows: [CGRect]) async throws -> ScreenSnapshot {
        guard let displayID = screen.displayID,
              let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.displayNotFound
        }

        let ownApps = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
        let config = SCStreamConfiguration()
        let scale = screen.backingScaleFactor
        config.width = Int(CGFloat(display.width) * scale)
        config.height = Int(CGFloat(display.height) * scale)
        config.showsCursor = UserDefaults.standard.bool(forKey: SettingsKey.showCursor)
        config.captureResolution = .best

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        let bounds = CGDisplayBounds(displayID)
        let localWindows = windows
            .filter { $0.intersects(bounds) }
            .map { $0.offsetBy(dx: -bounds.minX, dy: -bounds.minY) }

        return ScreenSnapshot(image: image,
                              screen: screen,
                              displayID: displayID,
                              displayBounds: bounds,
                              windowFrames: localWindows)
    }

    /// Normal-level windows of other apps, ordered front to back, in global Quartz coordinates.
    private static func visibleWindowFrames() -> [CGRect] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        return list.compactMap { info in
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  (info[kCGWindowOwnerPID as String] as? Int32) != ownPID,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: boundsDict),
                  rect.width > 40, rect.height > 40 else { return nil }
            return rect
        }
    }
}

extension NSScreen {
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    static var underMouse: NSScreen? {
        let location = NSEvent.mouseLocation
        return screens.first { NSMouseInRect(location, $0.frame, false) } ?? main
    }
}
