import AppKit

/// The editing canvas: shows the screenshot at its natural point size
/// (zooming is handled by the enclosing NSScrollView magnification) and
/// manages annotation input, undo/redo and inline text editing.
final class CanvasView: NSView, NSTextFieldDelegate {
    let baseImage: NSImage
    lazy var blurredImage: NSImage? = ImageRenderer.blurredImage(from: baseImage)

    private(set) var annotations: [Annotation] = []
    private var redoStack: [Annotation] = []
    private var current: Annotation?

    var tool: Tool = .arrow {
        didSet { commitTextEditing() }
    }
    var color: NSColor = .systemRed
    var lineWidth: CGFloat = 4
    var fontName: String = "System"
    var fontSize: CGFloat = 28
    private var badgeCount = 0

    /// Called whenever the annotation list changes (for undo/redo buttons).
    var onChange: (() -> Void)?

    private weak var editingField: NSTextField?
    private var editingOrigin: CGPoint = .zero

    var canUndo: Bool { !annotations.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    var currentFont: NSFont {
        if fontName == "System" { return .systemFont(ofSize: fontSize) }
        return NSFont(name: fontName, size: fontSize) ?? .systemFont(ofSize: fontSize)
    }

    init(image: NSImage) {
        self.baseImage = image
        super.init(frame: CGRect(origin: .zero, size: image.size))
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        baseImage.draw(in: bounds, from: .zero, operation: .copy, fraction: 1,
                       respectFlipped: true, hints: nil)
        for annotation in annotations {
            ImageRenderer.draw(annotation, imageSize: baseImage.size, blurred: blurredImage)
        }
        if let current {
            if current.tool.isBlur {
                // While dragging, show a dashed outline instead of the live blur.
                let outline = ImageRenderer.blurClipPath(for: current)
                outline.lineWidth = 1.5
                outline.setLineDash([6, 4], count: 2, phase: 0)
                NSColor.white.setStroke()
                outline.stroke()
                outline.setLineDash([6, 4], count: 2, phase: 6)
                NSColor.black.setStroke()
                outline.stroke()
            } else {
                ImageRenderer.draw(current, imageSize: baseImage.size, blurred: blurredImage)
            }
        }
    }

    // MARK: - Mouse input

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        commitTextEditing()

        switch tool {
        case .text:
            beginTextEditing(at: point)
        case .badge:
            badgeCount += 1
            var annotation = makeAnnotation(at: point)
            annotation.badgeNumber = badgeCount
            push(annotation)
        default:
            current = makeAnnotation(at: point)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard current != nil else { return }
        let point = convert(event.locationInWindow, from: nil)
        current?.end = point
        if tool == .blurLasso { current?.points.append(point) }
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard var annotation = current else { return }
        current = nil
        let point = convert(event.locationInWindow, from: nil)
        annotation.end = point
        if tool == .blurLasso { annotation.points.append(point) }

        let dragDistance = hypot(annotation.end.x - annotation.start.x,
                                 annotation.end.y - annotation.start.y)
        let meaningful = annotation.tool == .blurLasso ? annotation.points.count > 3 : dragDistance > 3
        if meaningful {
            push(annotation)
        } else {
            needsDisplay = true
        }
    }

    private func makeAnnotation(at point: CGPoint) -> Annotation {
        Annotation(tool: tool, start: point, end: point, points: [point],
                   color: color, lineWidth: lineWidth)
    }

    /// Adopts annotations coming from another editor (e.g. detaching the
    /// in-place editor into a window).
    func adoptAnnotations(_ list: [Annotation]) {
        annotations = list
        redoStack.removeAll()
        badgeCount = list.filter { $0.tool == .badge }.map(\.badgeNumber).max() ?? 0
        needsDisplay = true
        onChange?()
    }

    // MARK: - Undo / redo

    private func push(_ annotation: Annotation) {
        annotations.append(annotation)
        redoStack.removeAll()
        needsDisplay = true
        onChange?()
    }

    @objc func undo(_ sender: Any?) {
        commitTextEditing()
        guard let last = annotations.popLast() else { return }
        if last.tool == .badge { badgeCount = max(0, badgeCount - 1) }
        redoStack.append(last)
        needsDisplay = true
        onChange?()
    }

    @objc func redo(_ sender: Any?) {
        guard let last = redoStack.popLast() else { return }
        if last.tool == .badge { badgeCount += 1 }
        annotations.append(last)
        needsDisplay = true
        onChange?()
    }

    override func responds(to aSelector: Selector!) -> Bool {
        // Keep menu items enabled only when applicable.
        if aSelector == #selector(undo(_:)) { return canUndo }
        if aSelector == #selector(redo(_:)) { return canRedo }
        return super.responds(to: aSelector)
    }

    // MARK: - Inline text editing

    private func beginTextEditing(at point: CGPoint) {
        let font = currentFont
        let height = font.pointSize * 1.5
        let width = max(160, bounds.width - point.x - 8)
        let field = NSTextField(frame: CGRect(x: point.x, y: point.y, width: width, height: height))
        field.font = font
        field.textColor = color
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .default
        field.placeholderString = "Text…"
        field.delegate = self
        addSubview(field)
        editingField = field
        editingOrigin = point
        window?.makeFirstResponder(field)
    }

    func commitTextEditing() {
        guard let field = editingField else { return }
        editingField = nil
        let text = field.stringValue
        let origin = CGPoint(x: field.frame.origin.x + 2, y: field.frame.origin.y)
        field.removeFromSuperview()
        window?.makeFirstResponder(self)
        guard !text.isEmpty else { return }
        var annotation = makeAnnotation(at: origin)
        annotation.tool = .text
        annotation.text = text
        annotation.font = currentFont
        push(annotation)
    }

    private func cancelTextEditing() {
        editingField?.removeFromSuperview()
        editingField = nil
        window?.makeFirstResponder(self)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        commitTextEditing()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            commitTextEditing()
            return true
        }
        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            cancelTextEditing()
            return true
        }
        return false
    }
}
