import AppKit
import ServiceManagement

enum ImageFormat: String, CaseIterable {
    case png
    case jpeg

    var fileExtension: String { self == .png ? "png" : "jpg" }
    var title: String { self == .png ? "PNG" : "JPEG" }
    var fileType: NSBitmapImageRep.FileType { self == .png ? .png : .jpeg }
}

enum Settings {
    private static let defaults = UserDefaults.standard

    static func registerDefaults() {
        defaults.register(defaults: [
            "openEditor": true,
            "copyToClipboard": true,
            "playSound": true,
            "windowShadow": true,
            "filenamePrefix": "Screenshot",
            "format": ImageFormat.png.rawValue,
        ])
    }

    static var destinationURL: URL {
        get {
            if let path = defaults.string(forKey: "destinationPath"), !path.isEmpty {
                return URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
            }
            return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)
        }
        set { defaults.set(newValue.path, forKey: "destinationPath") }
    }

    static var format: ImageFormat {
        get { ImageFormat(rawValue: defaults.string(forKey: "format") ?? "png") ?? .png }
        set { defaults.set(newValue.rawValue, forKey: "format") }
    }

    static var filenamePrefix: String {
        get { defaults.string(forKey: "filenamePrefix") ?? "Screenshot" }
        set { defaults.set(newValue, forKey: "filenamePrefix") }
    }

    static var openEditor: Bool {
        get { defaults.bool(forKey: "openEditor") }
        set { defaults.set(newValue, forKey: "openEditor") }
    }

    static var copyToClipboard: Bool {
        get { defaults.bool(forKey: "copyToClipboard") }
        set { defaults.set(newValue, forKey: "copyToClipboard") }
    }

    static var playSound: Bool {
        get { defaults.bool(forKey: "playSound") }
        set { defaults.set(newValue, forKey: "playSound") }
    }

    static var windowShadow: Bool {
        get { defaults.bool(forKey: "windowShadow") }
        set { defaults.set(newValue, forKey: "windowShadow") }
    }

    // MARK: - Configurable hotkeys

    static func hotkey(for mode: CaptureManager.Mode) -> Hotkey {
        if let data = defaults.data(forKey: "hotkey-\(mode.rawValue)"),
           let hotkey = try? JSONDecoder().decode(Hotkey.self, from: data) {
            return hotkey
        }
        return Hotkey.defaultHotkey(for: mode)
    }

    static func setHotkey(_ hotkey: Hotkey, for mode: CaptureManager.Mode) {
        if let data = try? JSONEncoder().encode(hotkey) {
            defaults.set(data, forKey: "hotkey-\(mode.rawValue)")
        }
        NotificationCenter.default.post(name: .hotkeysChanged, object: nil)
    }

    static func resetHotkeys() {
        for mode in CaptureManager.Mode.allCases {
            defaults.removeObject(forKey: "hotkey-\(mode.rawValue)")
        }
        NotificationCenter.default.post(name: .hotkeysChanged, object: nil)
    }

    static var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("MScreenshot: launch-at-login change failed: \(error)")
            }
        }
    }
}
