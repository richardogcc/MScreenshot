import AppKit

/// A button that records a keyboard shortcut: click it, press the new
/// combination (must include ⌘, ⌥ or ⌃, or be an F-key), Esc cancels.
final class KeyRecorderButton: NSButton {
    var hotkey: Hotkey? {
        didSet { refreshTitle() }
    }
    var onChange: ((Hotkey) -> Void)?

    private var monitor: Any?
    private var isRecording = false {
        didSet { refreshTitle() }
    }

    init() {
        super.init(frame: .zero)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(toggleRecording)
        widthAnchor.constraint(greaterThanOrEqualToConstant: 110).isActive = true
        refreshTitle()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func refreshTitle() {
        if isRecording {
            title = "Press keys…"
        } else {
            title = hotkey?.display ?? "Record shortcut"
        }
    }

    @objc private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 { // esc cancels
                self.stopRecording()
                return nil
            }
            let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
            let isFunctionKey = (kVKF1Range).contains(Int(event.keyCode))
            let hasRealModifier = flags.contains(.command) || flags.contains(.option) || flags.contains(.control)
            guard hasRealModifier || isFunctionKey else {
                NSSound.beep()
                return nil
            }
            let recorded = Hotkey(keyCode: UInt32(event.keyCode),
                                  carbonModifiers: Hotkey.carbonModifiers(from: flags),
                                  character: Hotkey.displayCharacter(for: event))
            self.stopRecording()
            self.hotkey = recorded
            self.onChange?(recorded)
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        isRecording = false
    }
}

// F1–F12 key codes are non-contiguous; this covers the usual ones.
private let kVKF1Range: Set<Int> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]
