import AppKit

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class CapturePreviewController {
    private let image: CGImage
    private let captureFrame: CGRect
    private var previewWindow: NSPanel?
    private var toolbarWindow: NSPanel?
    private var canvasView: AnnotationCanvasView?
    private weak var arrowButton: NSButton?
    private weak var rectangleButton: NSButton?
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
        let canvas = AnnotationCanvasView(
            image: image,
            frame: NSRect(origin: .zero, size: captureFrame.size)
        )
        preview.contentView = canvas
        preview.orderFrontRegardless()
        previewWindow = preview
        canvasView = canvas

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
            if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "z" {
                self.undo()
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
        let buttonWidth: CGFloat = 70
        let toolbarSize = CGSize(width: buttonWidth * 6 + 20, height: 48)
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
        let arrow = makeButton(title: "Arrow", symbol: "arrow.up.right", action: #selector(selectArrow))
        arrow.setButtonType(.toggle)
        arrowButton = arrow
        stack.addArrangedSubview(arrow)
        let rectangle = makeButton(title: "Rect", symbol: "rectangle", action: #selector(selectRectangle))
        rectangle.setButtonType(.toggle)
        rectangleButton = rectangle
        stack.addArrangedSubview(rectangle)
        stack.addArrangedSubview(makeButton(title: "Undo", symbol: "arrow.uturn.backward", action: #selector(undo)))
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
        guard let renderedImage = canvasView?.renderedImage() else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let bitmap = NSBitmapImageRep(cgImage: renderedImage)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { return }
        pasteboard.setData(png, forType: .png)
        let callback = onCopy
        finish()
        callback?()
    }

    @objc private func saveAndClose() {
        guard let renderedImage = canvasView?.renderedImage() else { return }
        let callback = onSave
        finish()
        callback?(renderedImage)
    }

    @objc private func selectArrow() {
        setActiveTool(canvasView?.activeTool == .arrow ? .none : .arrow)
    }

    @objc private func selectRectangle() {
        setActiveTool(canvasView?.activeTool == .rectangle ? .none : .rectangle)
    }

    @objc private func undo() {
        canvasView?.undo()
    }

    private func setActiveTool(_ tool: AnnotationTool) {
        canvasView?.activeTool = tool
        arrowButton?.state = tool == .arrow ? .on : .off
        rectangleButton?.state = tool == .rectangle ? .on : .off
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
        canvasView = nil
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
