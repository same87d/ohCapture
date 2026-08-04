import AppKit

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class CapturePreviewController {
    private let image: CGImage
    private let captureFrame: CGRect
    private var previewWindow: NSPanel?
    private var toolbarWindow: NSPanel?
    private var keyMonitor: Any?
    private var onCopy: (() -> Void)?
    private var onSave: ((CGImage) -> Void)?
    private var onClose: (() -> Void)?

    init(image: CGImage, captureFrame: CGRect) {
        self.image = image
        self.captureFrame = captureFrame
    }

    func begin(
        onCopy: @escaping () -> Void,
        onSave: @escaping (CGImage) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.onCopy = onCopy
        self.onSave = onSave
        self.onClose = onClose

        let preview = makePanel(frame: captureFrame, level: .screenSaver)
        preview.ignoresMouseEvents = true
        let imageView = NSImageView(frame: NSRect(origin: .zero, size: captureFrame.size))
        imageView.image = NSImage(cgImage: image, size: captureFrame.size)
        imageView.imageScaling = .scaleAxesIndependently
        preview.contentView = imageView
        preview.orderFrontRegardless()
        previewWindow = preview

        let toolbar = makeToolbar()
        toolbar.setFrameOrigin(toolbarOrigin(for: toolbar.frame.size))
        NSApp.activate(ignoringOtherApps: true)
        toolbar.makeKeyAndOrderFront(nil)
        toolbarWindow = toolbar

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 {
                self.cancel()
                return nil
            }
            if event.keyCode == 36 {
                self.copyAndClose()
                return nil
            }
            if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "s" {
                self.saveAndClose()
                return nil
            }
            return event
        }
    }

    func close() {
        finish()
    }

    private func makePanel(frame: CGRect, level: NSWindow.Level) -> NSPanel {
        let panel = KeyablePanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = level
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }

    private func makeToolbar() -> NSPanel {
        let buttonWidth: CGFloat = 78
        let toolbarSize = CGSize(width: buttonWidth * 3 + 20, height: 48)
        let panel = makePanel(
            frame: CGRect(origin: .zero, size: toolbarSize),
            level: NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue + 1)
        )

        let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: toolbarSize))
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 10
        effect.layer?.masksToBounds = true

        let stack = NSStackView(frame: effect.bounds.insetBy(dx: 10, dy: 8))
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.distribution = .fillEqually
        stack.spacing = 4
        stack.addArrangedSubview(makeButton(title: "Copy", symbol: "doc.on.doc", action: #selector(copyAndClose)))
        stack.addArrangedSubview(makeButton(title: "Save", symbol: "square.and.arrow.down", action: #selector(saveAndClose)))
        stack.addArrangedSubview(makeButton(title: "Close", symbol: "xmark", action: #selector(cancel)))
        effect.addSubview(stack)
        panel.contentView = effect
        return panel
    }

    private func makeButton(title: String, symbol: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .recessed
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        button.imagePosition = .imageLeading
        return button
    }

    private func toolbarOrigin(for size: CGSize) -> CGPoint {
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(captureFrame) }) ?? NSScreen.main
        let available = screen?.visibleFrame ?? captureFrame
        let desiredBelow = CGPoint(
            x: min(max(captureFrame.maxX - size.width, available.minX), available.maxX - size.width),
            y: captureFrame.minY - size.height - 8
        )
        if desiredBelow.y >= available.minY { return desiredBelow }
        return CGPoint(
            x: desiredBelow.x,
            y: min(captureFrame.maxY + 8, available.maxY - size.height)
        )
    }

    @objc private func copyAndClose() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { return }
        pasteboard.setData(png, forType: .png)
        let callback = onCopy
        finish()
        callback?()
    }

    @objc private func saveAndClose() {
        let callback = onSave
        finish()
        callback?(image)
    }

    @objc private func cancel() {
        let callback = onClose
        finish()
        callback?()
    }

    private func finish() {
        previewWindow?.orderOut(nil)
        toolbarWindow?.orderOut(nil)
        previewWindow = nil
        toolbarWindow = nil
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        onCopy = nil
        onSave = nil
        onClose = nil
    }

    deinit {
        finish()
    }
}
