import AppKit

final class SettingsWindowController: NSWindowController {
    private var pathLabel: NSTextField!
    private var prefixField: NSTextField!
    private var recorders: [CaptureManager.Mode: KeyRecorderButton] = [:]

    init() {
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 500, height: 460),
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "MScreenshot Settings"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        refresh()
        window?.center()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func refresh() {
        pathLabel.stringValue = Settings.destinationURL.path
        prefixField.stringValue = Settings.filenamePrefix
        for (mode, recorder) in recorders {
            recorder.hotkey = Settings.hotkey(for: mode)
        }
    }

    // MARK: - UI

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        pathLabel = NSTextField(labelWithString: Settings.destinationURL.path)
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let chooseButton = NSButton(title: "Choose…", target: self, action: #selector(chooseDestination))
        let pathRow = NSStackView(views: [pathLabel, chooseButton])
        pathRow.orientation = .horizontal

        let formatPopup = NSPopUpButton()
        formatPopup.addItems(withTitles: ImageFormat.allCases.map { $0.title })
        formatPopup.selectItem(at: ImageFormat.allCases.firstIndex(of: Settings.format) ?? 0)
        formatPopup.target = self
        formatPopup.action = #selector(formatChanged(_:))

        prefixField = NSTextField(string: Settings.filenamePrefix)
        prefixField.target = self
        prefixField.action = #selector(prefixChanged(_:))
        prefixField.widthAnchor.constraint(greaterThanOrEqualToConstant: 180).isActive = true
        if let cell = prefixField.cell as? NSTextFieldCell { cell.sendsActionOnEndEditing = true }

        let grid = NSGridView(views: [
            [label("Save to:"), pathRow],
            [label("Format:"), formatPopup],
            [label("Filename prefix:"), prefixField],
        ])
        grid.rowSpacing = 10
        grid.columnSpacing = 12
        grid.column(at: 0).xPlacement = .trailing

        // Shortcut recorders
        var shortcutRows: [[NSView]] = []
        for mode in [CaptureManager.Mode.selection, .window, .fullScreen] {
            let recorder = KeyRecorderButton()
            recorder.hotkey = Settings.hotkey(for: mode)
            recorder.onChange = { hotkey in Settings.setHotkey(hotkey, for: mode) }
            recorders[mode] = recorder
            shortcutRows.append([label("\(mode.title):"), recorder])
        }
        let resetButton = NSButton(title: "Restore Defaults", target: self, action: #selector(resetShortcuts))
        shortcutRows.append([NSGridCell.emptyContentView, resetButton])
        let shortcutGrid = NSGridView(views: shortcutRows)
        shortcutGrid.rowSpacing = 8
        shortcutGrid.columnSpacing = 12
        shortcutGrid.column(at: 0).xPlacement = .trailing

        let editorCheck = checkbox("Open editor after capture", Settings.openEditor, #selector(toggleEditor(_:)))
        let clipboardCheck = checkbox("Copy capture to clipboard automatically", Settings.copyToClipboard, #selector(toggleClipboard(_:)))
        let soundCheck = checkbox("Capture sound", Settings.playSound, #selector(toggleSound(_:)))
        let shadowCheck = checkbox("Include window shadow in window captures", Settings.windowShadow, #selector(toggleShadow(_:)))
        let loginCheck = checkbox("Open MScreenshot at login", Settings.launchAtLogin, #selector(toggleLogin(_:)))

        let shortcutsHeader = NSTextField(labelWithString: "Keyboard Shortcuts")
        shortcutsHeader.font = .boldSystemFont(ofSize: NSFont.systemFontSize)

        let stack = NSStackView(views: [grid, separator(),
                                        editorCheck, clipboardCheck, soundCheck, shadowCheck, loginCheck,
                                        separator(), shortcutsHeader, shortcutGrid])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    private func label(_ text: String) -> NSTextField {
        NSTextField(labelWithString: text)
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }

    private func checkbox(_ title: String, _ state: Bool, _ action: Selector) -> NSButton {
        let button = NSButton(checkboxWithTitle: title, target: self, action: action)
        button.state = state ? .on : .off
        return button
    }

    // MARK: - Actions

    @objc private func chooseDestination() {
        guard let window else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = Settings.destinationURL
        panel.prompt = "Choose"
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Settings.destinationURL = url
            self?.pathLabel.stringValue = url.path
        }
    }

    @objc private func formatChanged(_ sender: NSPopUpButton) {
        Settings.format = ImageFormat.allCases[sender.indexOfSelectedItem]
    }

    @objc private func prefixChanged(_ sender: NSTextField) {
        let value = sender.stringValue.trimmingCharacters(in: .whitespaces)
        Settings.filenamePrefix = value.isEmpty ? "Screenshot" : value
    }

    @objc private func resetShortcuts() {
        Settings.resetHotkeys()
        for (mode, recorder) in recorders {
            recorder.hotkey = Settings.hotkey(for: mode)
        }
    }

    @objc private func toggleEditor(_ sender: NSButton) { Settings.openEditor = sender.state == .on }
    @objc private func toggleClipboard(_ sender: NSButton) { Settings.copyToClipboard = sender.state == .on }
    @objc private func toggleSound(_ sender: NSButton) { Settings.playSound = sender.state == .on }
    @objc private func toggleShadow(_ sender: NSButton) { Settings.windowShadow = sender.state == .on }
    @objc private func toggleLogin(_ sender: NSButton) {
        Settings.launchAtLogin = sender.state == .on
        sender.state = Settings.launchAtLogin ? .on : .off
    }
}
