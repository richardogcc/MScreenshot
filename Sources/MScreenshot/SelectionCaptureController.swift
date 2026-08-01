import AppKit

/// Full-screen dimmed overlays that let the user drag a selection
/// rectangle, then capture that region for in-place editing.
final class SelectionCaptureController {
    static let shared = SelectionCaptureController()

    private var windows: [OverlayWindow] = []
    private var completion: ((NSImage, CGRect) -> Void)?

    var isActive: Bool { !windows.isEmpty }

    func begin(completion: @escaping (NSImage, CGRect) -> Void) {
        guard windows.isEmpty else { return }
        self.completion = completion
        for screen in NSScreen.screens {
            let window = OverlayWindow(screen: screen)
            windows.append(window)
            window.makeKeyAndOrderFront(nil)
            window.makeFirstResponder(window.contentView)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func cancel() {
        teardown()
        completion = nil
    }

    /// `globalRect` is in Cocoa global screen coordinates.
    func finish(globalRect: CGRect) {
        let completion = self.completion
        self.completion = nil
        teardown()
        guard globalRect.width >= 4, globalRect.height >= 4 else { return }
        // Give the window server a beat to actually remove the overlays.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            Task { @MainActor in
                guard let image = await ScreenCapturer.capture(cocoaRect: globalRect) else { return }
                completion?(image, globalRect)
            }
        }
    }

    private func teardown() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
    }
}

private final class OverlayWindow: NSWindow {
    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .screenSaver
        contentView = SelectionView()
    }

    override var canBecomeKey: Bool { true }
}

private final class SelectionView: NSView {
    private var startPoint: CGPoint?
    private var currentPoint: CGPoint?

    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    private var selectionRect: CGRect? {
        guard let start = startPoint, let current = currentPoint else { return nil }
        return CGRect(x: min(start.x, current.x), y: min(start.y, current.y),
                      width: abs(current.x - start.x), height: abs(current.y - start.y))
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.25).setFill()
        bounds.fill()
        guard let rect = selectionRect, rect.width > 0, rect.height > 0 else { return }

        NSGraphicsContext.current?.cgContext.clear(rect)
        NSColor.white.setStroke()
        let outline = NSBezierPath(rect: rect.insetBy(dx: -0.5, dy: -0.5))
        outline.lineWidth = 1
        outline.stroke()

        let label = "\(Int(rect.width)) × \(Int(rect.height))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = label.size(withAttributes: attributes)
        let padding: CGFloat = 5
        var origin = CGPoint(x: rect.maxX - size.width - padding, y: rect.minY - size.height - padding * 2)
        if origin.y < 0 { origin.y = rect.minY + padding }
        origin.x = max(padding, origin.x)
        let badge = CGRect(x: origin.x - padding, y: origin.y - padding / 2,
                           width: size.width + padding * 2, height: size.height + padding)
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: badge, xRadius: 4, yRadius: 4).fill()
        label.draw(at: origin, withAttributes: attributes)
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        guard let rect = selectionRect, let window else {
            SelectionCaptureController.shared.cancel()
            return
        }
        startPoint = nil
        currentPoint = nil
        if rect.width < 4 || rect.height < 4 {
            SelectionCaptureController.shared.cancel()
            return
        }
        let screenRect = window.convertToScreen(convert(rect, to: nil))
        SelectionCaptureController.shared.finish(globalRect: screenRect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // esc
            SelectionCaptureController.shared.cancel()
        } else {
            super.keyDown(with: event)
        }
    }
}
