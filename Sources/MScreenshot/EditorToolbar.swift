import AppKit

/// Annotation toolbar shared by the editor window and the in-place editor.
final class EditorToolbar {
    enum Style {
        case window
        case inPlace
    }

    let view: NSStackView
    private let canvas: CanvasView
    private var undoButton: NSButton!
    private var redoButton: NSButton!

    var onCopy: (() -> Void)?
    var onSave: (() -> Void)?
    var onDetach: (() -> Void)?
    var onDiscard: (() -> Void)?

    static let tools: [(Tool, String, String)] = [
        (.arrow, "arrow.up.right", "Arrow"),
        (.line, "line.diagonal", "Line"),
        (.rect, "rectangle", "Rectangle"),
        (.ellipse, "circle", "Ellipse"),
        (.highlight, "highlighter", "Highlighter"),
        (.badge, "1.circle.fill", "Number badge"),
        (.text, "textformat", "Text"),
        (.blurRect, "square.dotted", "Rectangular blur"),
        (.blurEllipse, "circle.dotted", "Circular blur"),
        (.blurLasso, "lasso", "Freeform blur"),
    ]

    static let fontOptions: [(String, String)] = [
        ("System", "System"),
        ("Helvetica Neue", "Helvetica Neue"),
        ("Arial", "Arial"),
        ("Georgia", "Georgia"),
        ("Times New Roman", "Times New Roman"),
        ("Courier New", "Courier New"),
        ("Menlo", "Menlo"),
        ("Marker Felt", "Marker Felt"),
        ("Chalkboard SE", "Chalkboard SE"),
        ("Impact", "Impact"),
    ]

    static let fontSizes: [CGFloat] = [14, 18, 22, 28, 36, 48, 64, 96]
    static let lineWidths: [CGFloat] = [2, 4, 6, 8, 12]

    init(canvas: CanvasView, style: Style) {
        self.canvas = canvas

        let toolControl = NSSegmentedControl(images: Self.tools.map { Self.symbol($0.1) },
                                             trackingMode: .selectOne,
                                             target: nil, action: nil)
        for (index, tool) in Self.tools.enumerated() {
            toolControl.setToolTip(tool.2, forSegment: index)
        }
        toolControl.selectedSegment = 0

        let colorWell = NSColorWell()
        colorWell.color = canvas.color
        colorWell.toolTip = "Color"
        colorWell.widthAnchor.constraint(equalToConstant: 44).isActive = true

        let widthPopup = NSPopUpButton()
        widthPopup.addItems(withTitles: Self.lineWidths.map { "\(Int($0)) pt" })
        widthPopup.selectItem(at: Self.lineWidths.firstIndex(of: canvas.lineWidth) ?? 1)
        widthPopup.toolTip = "Line width"

        let fontPopup = NSPopUpButton()
        fontPopup.addItems(withTitles: Self.fontOptions.map { $0.0 })
        fontPopup.toolTip = "Text font"

        let fontSizePopup = NSPopUpButton()
        fontSizePopup.addItems(withTitles: Self.fontSizes.map { "\(Int($0))" })
        fontSizePopup.selectItem(at: Self.fontSizes.firstIndex(of: canvas.fontSize) ?? 3)
        fontSizePopup.toolTip = "Text size"

        undoButton = NSButton(image: Self.symbol("arrow.uturn.backward"), target: nil, action: nil)
        undoButton.bezelStyle = .texturedRounded
        undoButton.toolTip = "Undo (⌘Z)"
        redoButton = NSButton(image: Self.symbol("arrow.uturn.forward"), target: nil, action: nil)
        redoButton.bezelStyle = .texturedRounded
        redoButton.toolTip = "Redo (⇧⌘Z)"

        let copyButton = NSButton(title: "Copy", target: nil, action: nil)
        copyButton.bezelStyle = .texturedRounded
        copyButton.toolTip = "Copy to clipboard"

        let saveButton = NSButton(title: "Save", target: nil, action: nil)
        saveButton.bezelStyle = .texturedRounded
        saveButton.keyEquivalent = "s"
        saveButton.keyEquivalentModifierMask = [.command]
        saveButton.toolTip = "Save (⌘S)"

        var views: [NSView] = [toolControl, Self.separator(), colorWell, widthPopup,
                               fontPopup, fontSizePopup, NSView(),
                               undoButton, redoButton, Self.separator()]

        var detachButton: NSButton?
        var discardButton: NSButton?
        if style == .inPlace {
            let button = NSButton(image: Self.symbol("arrow.up.left.and.arrow.down.right"), target: nil, action: nil)
            button.bezelStyle = .texturedRounded
            button.toolTip = "Open in editor window"
            views.append(button)
            detachButton = button
        }

        views += [copyButton, saveButton]

        if style == .inPlace {
            let button = NSButton(image: Self.symbol("xmark"), target: nil, action: nil)
            button.bezelStyle = .texturedRounded
            button.toolTip = "Discard (Esc)"
            views.append(button)
            discardButton = button
        }

        view = NSStackView(views: views)
        view.orientation = .horizontal
        view.spacing = 8
        view.edgeInsets = NSEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)

        toolControl.target = self
        toolControl.action = #selector(toolChanged(_:))
        colorWell.target = self
        colorWell.action = #selector(colorChanged(_:))
        widthPopup.target = self
        widthPopup.action = #selector(widthChanged(_:))
        fontPopup.target = self
        fontPopup.action = #selector(fontChanged(_:))
        fontSizePopup.target = self
        fontSizePopup.action = #selector(fontSizeChanged(_:))
        undoButton.target = self
        undoButton.action = #selector(undoPressed)
        redoButton.target = self
        redoButton.action = #selector(redoPressed)
        copyButton.target = self
        copyButton.action = #selector(copyPressed)
        saveButton.target = self
        saveButton.action = #selector(savePressed)
        detachButton?.target = self
        detachButton?.action = #selector(detachPressed)
        discardButton?.target = self
        discardButton?.action = #selector(discardPressed)

        updateUndoButtons()
    }

    func updateUndoButtons() {
        undoButton.isEnabled = canvas.canUndo
        redoButton.isEnabled = canvas.canRedo
    }

    private static func symbol(_ name: String) -> NSImage {
        NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage()
    }

    private static func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    // MARK: - Actions

    @objc private func toolChanged(_ sender: NSSegmentedControl) {
        canvas.tool = Self.tools[sender.selectedSegment].0
    }

    @objc private func colorChanged(_ sender: NSColorWell) {
        canvas.color = sender.color
    }

    @objc private func widthChanged(_ sender: NSPopUpButton) {
        canvas.lineWidth = Self.lineWidths[sender.indexOfSelectedItem]
    }

    @objc private func fontChanged(_ sender: NSPopUpButton) {
        canvas.fontName = Self.fontOptions[sender.indexOfSelectedItem].1
    }

    @objc private func fontSizeChanged(_ sender: NSPopUpButton) {
        canvas.fontSize = Self.fontSizes[sender.indexOfSelectedItem]
    }

    @objc private func undoPressed() {
        canvas.undo(nil)
        updateUndoButtons()
    }

    @objc private func redoPressed() {
        canvas.redo(nil)
        updateUndoButtons()
    }

    @objc private func copyPressed() { onCopy?() }
    @objc private func savePressed() { onSave?() }
    @objc private func detachPressed() { onDetach?() }
    @objc private func discardPressed() { onDiscard?() }
}
