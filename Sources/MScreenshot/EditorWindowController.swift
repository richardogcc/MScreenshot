import AppKit
import UniformTypeIdentifiers

/// NSClipView that keeps the document centered when it is smaller than
/// the visible area.
final class CenteredClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds)
        guard let documentView else { return rect }
        if documentView.frame.width < rect.width {
            rect.origin.x = (documentView.frame.width - rect.width) / 2
        }
        if documentView.frame.height < rect.height {
            rect.origin.y = (documentView.frame.height - rect.height) / 2
        }
        return rect
    }
}

final class EditorWindowController: NSWindowController, NSWindowDelegate {
    private static var controllers: [EditorWindowController] = []

    static func openEditor(image: NSImage, annotations: [Annotation] = []) {
        let controller = EditorWindowController(image: image, annotations: annotations)
        controllers.append(controller)
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private let canvas: CanvasView
    private var scrollView: NSScrollView!
    private var toolbar: EditorToolbar!

    init(image: NSImage, annotations: [Annotation] = []) {
        canvas = CanvasView(image: image)
        if !annotations.isEmpty { canvas.adoptAnnotations(annotations) }

        let screenFrame = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let toolbarHeight: CGFloat = 48
        let maxContent = CGSize(width: screenFrame.width * 0.9,
                                height: screenFrame.height * 0.9 - toolbarHeight)
        let fitScale = min(1, min(maxContent.width / image.size.width,
                                  maxContent.height / image.size.height))
        let contentSize = CGSize(width: max(760, image.size.width * fitScale),
                                 height: image.size.height * fitScale + toolbarHeight)

        let window = NSWindow(contentRect: CGRect(origin: .zero, size: contentSize),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "Screenshot — \(Int(image.size.width))×\(Int(image.size.height))"
        window.center()
        super.init(window: window)
        window.delegate = self
        window.isReleasedWhenClosed = false

        buildUI(toolbarHeight: toolbarHeight)
        canvas.onChange = { [weak self] in self?.toolbar.updateUndoButtons() }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.scrollView.magnification = fitScale
            self.window?.makeFirstResponder(self.canvas)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - UI construction

    private func buildUI(toolbarHeight: CGFloat) {
        guard let contentView = window?.contentView else { return }

        toolbar = EditorToolbar(canvas: canvas, style: .window)
        toolbar.onCopy = { [weak self] in self?.copyToClipboard() }
        toolbar.onSave = { [weak self] in self?.saveEditor(nil) }
        let toolbarView = toolbar.view
        toolbarView.translatesAutoresizingMaskIntoConstraints = false

        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentView = CenteredClipView()
        scrollView.documentView = canvas
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.1
        scrollView.maxMagnification = 8
        scrollView.backgroundColor = .windowBackgroundColor

        contentView.addSubview(toolbarView)
        contentView.addSubview(scrollView)
        NSLayoutConstraint.activate([
            toolbarView.topAnchor.constraint(equalTo: contentView.topAnchor),
            toolbarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            toolbarView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            toolbarView.heightAnchor.constraint(equalToConstant: toolbarHeight),
            scrollView.topAnchor.constraint(equalTo: toolbarView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
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
        guard let window else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = Settings.format == .png ? [.png] : [.jpeg]
        panel.nameFieldStringValue = "Screenshot.\(Settings.format.fileExtension)"
        panel.beginSheetModal(for: window) { [weak self] response in
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

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        Self.controllers.removeAll { $0 === self }
    }
}
