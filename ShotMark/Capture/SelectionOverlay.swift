import AppKit

/// Full-screen overlay showing a frozen snapshot of one display.
/// Hover highlights a window (click to take it), drag selects a region,
/// Space/Return takes the whole screen, Escape cancels.
@MainActor
final class SelectionOverlayController {
    private let window: OverlayWindow
    let snapshot: ScreenSnapshot

    init(snapshot: ScreenSnapshot, onFinish: @escaping @MainActor (ScreenSnapshot, CGRect?) -> Void) {
        self.snapshot = snapshot
        window = OverlayWindow(contentRect: snapshot.screen.frame,
                               styleMask: .borderless,
                               backing: .buffered,
                               defer: false)
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isOpaque = true
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true

        let view = SelectionView(snapshot: snapshot)
        view.onFinish = { [snapshot] rect in onFinish(snapshot, rect) }
        window.contentView = view
        window.setFrame(snapshot.screen.frame, display: false)
    }

    func show(makeKey: Bool) {
        if makeKey {
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(window.contentView)
        } else {
            window.orderFrontRegardless()
        }
        NSCursor.crosshair.set()
    }

    func close() {
        window.orderOut(nil)
        window.close()
    }
}

private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private final class SelectionView: NSView {
    let snapshot: ScreenSnapshot
    var onFinish: ((CGRect?) -> Void)?

    private lazy var backgroundImage = NSImage(cgImage: snapshot.image, size: snapshot.pointSize)
    private var dragStart: CGPoint?
    private var dragCurrent: CGPoint?
    private var mouseLocation: CGPoint?
    private var hoveredWindow: CGRect?

    init(snapshot: ScreenSnapshot) {
        self.snapshot = snapshot
        super.init(frame: CGRect(origin: .zero, size: snapshot.pointSize))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseMoved, .activeAlways, .inVisibleRect, .cursorUpdate],
                                       owner: self))
    }

    override func cursorUpdate(with event: NSEvent) { NSCursor.crosshair.set() }

    private var dragRect: CGRect? {
        guard let start = dragStart, let current = dragCurrent else { return nil }
        let rect = CGRect(x: min(start.x, current.x), y: min(start.y, current.y),
                          width: abs(current.x - start.x), height: abs(current.y - start.y))
        return rect.width >= 4 || rect.height >= 4 ? rect : nil
    }

    private var activeRect: CGRect? { dragRect ?? hoveredWindow }

    // MARK: Mouse & keyboard

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        mouseLocation = point
        hoveredWindow = snapshot.windowFrames.first { $0.contains(point) }?.intersection(bounds)
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        dragStart = convert(event.locationInWindow, from: nil)
        dragCurrent = dragStart
    }

    override func mouseDragged(with event: NSEvent) {
        dragCurrent = convert(event.locationInWindow, from: nil)
        mouseLocation = dragCurrent
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if let rect = dragRect {
            onFinish?(rect)
        } else if let window = hoveredWindow {
            onFinish?(window)
        }
        dragStart = nil
        dragCurrent = nil
        needsDisplay = true
    }

    override func rightMouseDown(with event: NSEvent) { onFinish?(nil) }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: onFinish?(nil)                          // Escape
        case 49, 36, 76: onFinish?(bounds)               // Space, Return, Enter
        default: super.keyDown(with: event)
        }
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        backgroundImage.draw(in: bounds, from: .zero, operation: .copy, fraction: 1,
                             respectFlipped: true, hints: nil)

        let dim = NSBezierPath(rect: bounds)
        if let rect = activeRect {
            dim.append(NSBezierPath(rect: rect))
            dim.windingRule = .evenOdd
        }
        NSColor.black.withAlphaComponent(0.4).setFill()
        dim.fill()

        if let rect = activeRect {
            let border = NSBezierPath(rect: rect.insetBy(dx: -1, dy: -1))
            border.lineWidth = 2
            NSColor.systemGreen.setStroke()
            border.stroke()
            drawSizeLabel(for: rect)
        }

        if dragRect == nil, let point = mouseLocation {
            drawCrosshair(at: point)
        }
    }

    private func drawCrosshair(at point: CGPoint) {
        let path = NSBezierPath()
        path.move(to: CGPoint(x: bounds.minX, y: point.y))
        path.line(to: CGPoint(x: bounds.maxX, y: point.y))
        path.move(to: CGPoint(x: point.x, y: bounds.minY))
        path.line(to: CGPoint(x: point.x, y: bounds.maxY))
        path.lineWidth = 1
        path.setLineDash([4, 4], count: 2, phase: 0)
        NSColor.white.withAlphaComponent(0.7).setStroke()
        path.stroke()
    }

    private func drawSizeLabel(for rect: CGRect) {
        let scale = snapshot.scale
        let text = "\(Int(rect.width * scale)) × \(Int(rect.height * scale))" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = text.size(withAttributes: attributes)
        var origin = CGPoint(x: rect.minX, y: rect.minY - size.height - 8)
        if origin.y < bounds.minY { origin.y = rect.minY + 4 }
        let background = CGRect(x: origin.x, y: origin.y, width: size.width + 10, height: size.height + 4)
        NSColor.black.withAlphaComponent(0.75).setFill()
        NSBezierPath(roundedRect: background, xRadius: 4, yRadius: 4).fill()
        text.draw(at: CGPoint(x: origin.x + 5, y: origin.y + 2), withAttributes: attributes)
    }
}
