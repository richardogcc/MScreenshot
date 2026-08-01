import AppKit
import ScreenCaptureKit

/// Captures a region of the screen with ScreenCaptureKit.
enum ScreenCapturer {

    /// `cocoaRect` is in global Cocoa screen coordinates (bottom-left origin).
    @MainActor
    static func capture(cocoaRect: CGRect) async -> NSImage? {
        let cgRect = cocoaToCG(cocoaRect)
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            guard let display = content.displays.first(where: { $0.frame.intersects(cgRect) }) else { return nil }

            let ownBundleID = Bundle.main.bundleIdentifier
            let ownApps = content.applications.filter { $0.bundleIdentifier == ownBundleID }
            let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])

            let scale = backingScale(for: display)
            let local = CGRect(x: cgRect.minX - display.frame.minX,
                               y: cgRect.minY - display.frame.minY,
                               width: cgRect.width,
                               height: cgRect.height)

            let config = SCStreamConfiguration()
            config.sourceRect = local
            config.width = Int(local.width * scale)
            config.height = Int(local.height * scale)
            config.showsCursor = false
            config.captureResolution = .best

            let cgImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            return NSImage(cgImage: cgImage, size: cocoaRect.size)
        } catch {
            NSLog("MScreenshot: selection capture failed: \(error)")
            showPermissionAlert()
            return nil
        }
    }

    private static func backingScale(for display: SCDisplay) -> CGFloat {
        for screen in NSScreen.screens {
            if let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
               id == display.displayID {
                return screen.backingScaleFactor
            }
        }
        return 2
    }

    private static func cocoaToCG(_ rect: CGRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.maxY ?? 0
        return CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    @MainActor
    private static func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording permission needed"
        alert.informativeText = "MScreenshot needs Screen Recording permission to capture the screen. Enable it in System Settings → Privacy & Security → Screen Recording, then try again."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
