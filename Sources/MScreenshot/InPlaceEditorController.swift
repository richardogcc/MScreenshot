import AppKit

/// Borderless window that lets a selection capture be edited "in place":
/// it sits exactly over the captured region with a floating toolbar.
final class InPlaceEditorController: NSWindowController, NSWindowDelegate {
    private static var controllers: [InPlaceEditorController] = []

    static func openEditor(image: NSImage, screenRect: CGRect) {
        let controller = InPlaceEditorController(image: image, screenRect: screenRect)
        controllers.append(controller)
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private let canvas: CanvasView
    private let capturedImage: NSImage
    private var toolbar: EditorToolbar!
    private var toolbarPanel: NSPanel!

    init(image: NSImage, screenRect: CGRect) {
        capturedImage = image
        canvas = CanvasView(image: image)

        let window = KeyableBorderlessWindow(contentRect: screenRect,
                                             styleMask: [.borderless],
                                             backing: .buffered, defer: false)
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.backgroundColor = .black
        window.hasShadow = true
        super.init(window: window)
        window.delegate = self
        window.contentView = canvas
        canvas.layer?.borderWidth = 2
        canvas.layer?.borderColor = NSColor.controlAccentColor.cgColor

        window.onEscape = { [weak self] in self?.close() }
        window.onReturn = { [weak self] in self?.saveEditor(nil) }

        buildToolbarPanel(screenRect: screenRect)
        canvas.onChange = { [weak self] in self?.toolbar.updateUndoButtons() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeFirstResponder(canvas)
    }

    private func buildToolbarPanel(screenRect: CGRect) {
        toolbar = EditorToolbar(canvas: canvas, style: .inPlace)
        toolbar.onCopy = { [weak self] in self?.copyToClipboard() }
        toolbar.onSave = { [weak self] in self?.saveEditor(nil) }
        toolbar.onDetach = { [weak self] in self?.detach() }
        toolbar.onDiscard = { [weak self] in self?.close() }

        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 10
        toolbar.view.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(toolbar.view)
        NSLayoutConstraint.activate([
            toolbar.view.topAnchor.constraint(equalTo: effect.topAnchor),
            toolbar.view.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
            toolbar.view.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            toolbar.view.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
        ])

        let size = toolbar.view.fittingSize
        let screen = window?.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? screenRect
        var x = screenRect.midX - size.width / 2
        x = max(visible.minX + 8, min(x, visible.maxX - size.width - 8))
        var y = screenRect.minY - size.height - 10
        if y < visible.minY {
            y = min(screenRect.maxY + 10, visible.maxY - size.height - 8)
        }

        let panel = NSPanel(contentRect: CGRect(x: x, y: y, width: size.width, height: size.height),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.becomesKeyOnlyIfNeeded = true
        panel.isReleasedWhenClosed = false
        panel.contentView = effect
        toolbarPanel = panel
        window?.addChildWindow(panel, ordered: .above)
    }

    // MARK: - Actions

    private func encodedImage(format: ImageFormat) -> Data? {
        canvas.commitTextEditing()
        return ImageRenderer.encode(base: canvas.baseImage, annotations: canvas.annotations, format: format)
    }

    private func copyToClipboard() {
        guard let data = encodedImage(format: .png) else { return }
        CaptureManager.shared.copyToPasteboard(data: data, format: .png)
    }

    @objc func saveEditor(_ sender: Any?) {
        guard let data = encodedImage(format: Settings.format) else { return }
        if CaptureManager.shared.saveToDestination(data: data) != nil {
            close()
        }
    }

    @objc func saveEditorAs(_ sender: Any?) {
        canvas.commitTextEditing()
        let panel = NSSavePanel()
        panel.allowedContentTypes = Settings.format == .png ? [.png] : [.jpeg]
        panel.nameFieldStringValue = "Screenshot.\(Settings.format.fileExtension)"
        panel.begin { [weak self] response in
            guard let self, response == .OK, let url = panel.url,
                  let data = self.encodedImage(format: Settings.format) else { return }
            do {
                try data.write(to: url)
                if Settings.copyToClipboard {
                    CaptureManager.shared.copyToPasteboard(data: data, format: Settings.format)
                }
                self.close()
            } catch {
                NSLog("MScreenshot: save-as failed: \(error)")
            }
        }
    }

    private func detach() {
        canvas.commitTextEditing()
        let annotations = canvas.annotations
        let image = capturedImage
        close()
        EditorWindowController.openEditor(image: image, annotations: annotations)
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        if let toolbarPanel {
            window?.removeChildWindow(toolbarPanel)
            toolbarPanel.orderOut(nil)
        }
        Self.controllers.removeAll { $0 === self }
    }
}

final class KeyableBorderlessWindow: NSWindow {
    var onEscape: (() -> Void)?
    var onReturn: (() -> Void)?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: // esc
            onEscape?()
        case 36, 76: // return / keypad enter
            onReturn?()
        default:
            super.keyDown(with: event)
        }
    }
}
