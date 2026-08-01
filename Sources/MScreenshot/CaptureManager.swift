import AppKit

final class CaptureManager {
    static let shared = CaptureManager()

    enum Mode: String, CaseIterable {
        case selection
        case window
        case fullScreen

        var title: String {
            switch self {
            case .selection: return "Capture Selection"
            case .window: return "Capture Window"
            case .fullScreen: return "Capture Full Screen"
            }
        }
    }

    func capture(_ mode: Mode) {
        // Small delay so the status bar menu can close before capturing.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            if mode == .selection {
                self.startSelectionCapture()
            } else {
                self.runScreencapture(mode)
            }
        }
    }

    // MARK: - Selection capture (custom overlay + in-place editor)

    private func startSelectionCapture() {
        guard !SelectionCaptureController.shared.isActive else { return }
        SelectionCaptureController.shared.begin { [weak self] image, screenRect in
            guard let self else { return }
            self.playCaptureSound()
            self.autoCopy(image: image)
            if Settings.openEditor {
                InPlaceEditorController.openEditor(image: image, screenRect: screenRect)
            } else {
                self.saveWithoutEditing(image: image)
            }
        }
    }

    // MARK: - Window / full screen capture (system screencapture tool)

    private func runScreencapture(_ mode: Mode) {
        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mscreenshot-\(UUID().uuidString).png")

        var args: [String] = []
        if !Settings.playSound { args.append("-x") }
        switch mode {
        case .window:
            args += ["-i", "-W"]
            if !Settings.windowShadow { args.append("-o") }
        case .fullScreen, .selection:
            break
        }
        args.append(tmpURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = args
        process.terminationHandler = { _ in
            DispatchQueue.main.async {
                // If the user cancelled (Esc), no file is written.
                guard FileManager.default.fileExists(atPath: tmpURL.path),
                      let image = NSImage(contentsOf: tmpURL) else { return }
                try? FileManager.default.removeItem(at: tmpURL)

                self.autoCopy(image: image)
                if Settings.openEditor {
                    EditorWindowController.openEditor(image: image)
                } else {
                    self.saveWithoutEditing(image: image)
                }
            }
        }
        do {
            try process.run()
        } catch {
            NSLog("MScreenshot: failed to run screencapture: \(error)")
        }
    }

    // MARK: - Shared plumbing

    /// Copies the freshly taken capture to the clipboard (before any editing).
    private func autoCopy(image: NSImage) {
        guard Settings.copyToClipboard,
              let data = ImageRenderer.encode(base: image, annotations: [], format: .png) else { return }
        copyToPasteboard(data: data, format: .png)
    }

    private func playCaptureSound() {
        guard Settings.playSound else { return }
        NSSound(named: "Pop")?.play()
    }

    private func saveWithoutEditing(image: NSImage) {
        guard let data = ImageRenderer.encode(base: image, annotations: [], format: Settings.format) else { return }
        _ = saveToDestination(data: data)
    }

    /// Writes encoded image data to the configured destination folder.
    /// Returns the written file URL, or nil on failure.
    @discardableResult
    func saveToDestination(data: Data) -> URL? {
        let dir = Settings.destinationURL
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
            let name = "\(Settings.filenamePrefix) \(formatter.string(from: Date())).\(Settings.format.fileExtension)"
            let url = dir.appendingPathComponent(name)
            try data.write(to: url)
            if Settings.copyToClipboard {
                copyToPasteboard(data: data, format: Settings.format)
            }
            return url
        } catch {
            NSLog("MScreenshot: failed to save capture: \(error)")
            let alert = NSAlert()
            alert.messageText = "Could not save the screenshot"
            alert.informativeText = error.localizedDescription
            alert.runModal()
            return nil
        }
    }

    func copyToPasteboard(data: Data, format: ImageFormat) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let type: NSPasteboard.PasteboardType = format == .png ? .png : NSPasteboard.PasteboardType("public.jpeg")
        pasteboard.setData(data, forType: type)
    }
}
