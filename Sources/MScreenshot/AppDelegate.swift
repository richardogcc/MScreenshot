import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.registerDefaults()
        setupMainMenu()
        setupStatusItem()
        rebuildStatusMenu()
        registerHotkeys()
        NotificationCenter.default.addObserver(self, selector: #selector(hotkeysChanged),
                                               name: .hotkeysChanged, object: nil)
    }

    // MARK: - Status bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "MScreenshot")
            image?.isTemplate = true
            button.image = image
        }
    }

    private func rebuildStatusMenu() {
        let menu = NSMenu()
        for mode in [CaptureManager.Mode.selection, .window, .fullScreen] {
            let hotkey = Settings.hotkey(for: mode)
            let item = NSMenuItem(title: mode.title, action: #selector(captureAction(_:)),
                                  keyEquivalent: hotkey.character.count == 1 ? hotkey.character.lowercased() : "")
            item.keyEquivalentModifierMask = hotkey.eventModifiers
            item.target = self
            item.representedObject = mode.rawValue
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(menuItem("Settings…", #selector(openSettings), ",", [.command]))
        menu.addItem(menuItem("About MScreenshot", #selector(showAbout), "", []))
        menu.addItem(.separator())
        menu.addItem(menuItem("Quit MScreenshot", #selector(NSApplication.terminate(_:)), "q", [.command]))
        statusItem.menu = menu
    }

    private func menuItem(_ title: String, _ action: Selector, _ key: String, _ mods: NSEvent.ModifierFlags) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = mods
        item.target = self
        return item
    }

    // MARK: - Global hotkeys

    private func registerHotkeys() {
        for (index, mode) in CaptureManager.Mode.allCases.enumerated() {
            let hotkey = Settings.hotkey(for: mode)
            HotkeyManager.shared.register(id: UInt32(index + 1),
                                          keyCode: hotkey.keyCode,
                                          modifiers: hotkey.carbonModifiers) {
                CaptureManager.shared.capture(mode)
            }
        }
    }

    @objc private func hotkeysChanged() {
        HotkeyManager.shared.unregisterAll()
        registerHotkeys()
        rebuildStatusMenu()
    }

    // MARK: - Actions

    @objc private func captureAction(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = CaptureManager.Mode(rawValue: raw) else { return }
        CaptureManager.shared.capture(mode)
    }

    @objc private func openSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.show()
    }

    @objc private func showAbout() {
        AboutPanelController.shared.show()
    }

    // MARK: - Main menu (key equivalents for editor/text fields)

    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "About MScreenshot", action: #selector(showAbout), keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit MScreenshot", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(NSMenuItem(title: "Save", action: #selector(EditorWindowController.saveEditor(_:)), keyEquivalent: "s"))
        let saveAs = NSMenuItem(title: "Save As…", action: #selector(EditorWindowController.saveEditorAs(_:)), keyEquivalent: "s")
        saveAs.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(saveAs)
        fileMenu.addItem(NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        fileItem.submenu = fileMenu
        mainMenu.addItem(fileItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redo)
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        NSApp.mainMenu = mainMenu
    }
}
