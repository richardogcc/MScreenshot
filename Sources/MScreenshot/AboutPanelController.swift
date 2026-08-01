import AppKit

/// Standardized About panel shared across the richardogcc utilities fleet:
/// a centered HUD card with the app icon, name, version, description and
/// license line. Clicking the card or pressing Esc dismisses it.
final class AboutPanelController {
    static let shared = AboutPanelController()

    private var panel: AboutPanel?

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        if let panel {
            panel.makeKeyAndOrderFront(nil)
            return
        }
        let card = AboutCardView()
        let panel = AboutPanel(contentRect: card.frame,
                               styleMask: .borderless,
                               backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.contentView = card
        let dismiss: () -> Void = { [weak self] in self?.close() }
        card.onDismiss = dismiss
        panel.onDismiss = dismiss
        panel.center()
        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
    }

    private func close() {
        panel?.orderOut(nil)
        panel = nil
    }
}

/// Borderless floating panel that can become key so Esc reaches it.
private final class AboutPanel: NSPanel {
    var onDismiss: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onDismiss?()
    }
}

/// The About card: app icon, name, version and license. Any click dismisses it.
private final class AboutCardView: NSView {
    var onDismiss: (() -> Void)?

    init() {
        super.init(frame: .zero)

        let card = NSVisualEffectView()
        card.material = .hudWindow
        card.blendingMode = .behindWindow
        card.state = .active
        card.wantsLayer = true
        card.layer?.cornerRadius = 14
        card.layer?.masksToBounds = true

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? "dev"

        let icon = NSImageView(image: NSApp.applicationIconImage ?? NSImage())
        icon.frame = NSRect(x: 0, y: 0, width: 72, height: 72)

        let lines: [(String, NSFont, NSColor)] = [
            ("MScreenshot", .systemFont(ofSize: 20, weight: .bold), .labelColor),
            ("Version \(version)", .systemFont(ofSize: 12), .secondaryLabelColor),
            ("Menu bar screenshot app with in-place annotation editing",
             .systemFont(ofSize: 12), .secondaryLabelColor),
            ("github.com/richardogcc/MScreenshot  ·  MIT License",
             .systemFont(ofSize: 11), .tertiaryLabelColor),
        ]
        let labels: [NSTextField] = lines.map { text, font, color in
            let label = NSTextField(labelWithString: text)
            label.font = font
            label.textColor = color
            label.alignment = .center
            label.sizeToFit()
            return label
        }

        let padding: CGFloat = 32
        let spacing: CGFloat = 8
        let contentWidth = max(labels.map { $0.frame.width }.max() ?? 0, 220)
        let textHeight = labels.reduce(0) { $0 + $1.frame.height } +
            spacing * CGFloat(labels.count - 1)
        let width = contentWidth + padding * 2
        let height = padding + icon.frame.height + 14 + textHeight + padding
        frame = NSRect(x: 0, y: 0, width: width, height: height)
        card.frame = bounds

        icon.setFrameOrigin(NSPoint(x: (width - icon.frame.width) / 2,
                                    y: height - padding - icon.frame.height))
        var y = height - padding - icon.frame.height - 14
        for label in labels {
            y -= label.frame.height
            label.frame = NSRect(x: padding, y: y, width: contentWidth,
                                 height: label.frame.height)
            card.addSubview(label)
            y -= spacing
        }
        card.addSubview(icon)
        addSubview(card)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {
        onDismiss?()
    }
}
