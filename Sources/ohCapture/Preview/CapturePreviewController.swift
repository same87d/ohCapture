import AppKit

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class CapturePreviewController {
    private let image: CGImage
    private let captureFrame: CGRect
    private let ocrService = OCRService()
    private var previewWindow: NSPanel?
    private var toolbarWindow: NSPanel?
    private var canvasView: AnnotationCanvasView?
    private weak var arrowButton: NSButton?
    private weak var rectangleButton: NSButton?
    private weak var textButton: NSButton?
    private weak var mosaicButton: NSButton?
    private weak var ocrButton: NSButton?
    private weak var translateButton: NSButton?
    private var isPresentingTextDialog = false
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

        let screen = targetScreen()
        let visibleFrame = screen?.visibleFrame ?? captureFrame
        let toolbar = makeToolbar()
        let previewFrame = PreviewLayout.fittedPreviewFrame(
            captureFrame: captureFrame,
            visibleFrame: visibleFrame
        )
        let preview = makePanel(frame: previewFrame, level: .floating)
        let canvas = AnnotationCanvasView(
            image: image,
            frame: NSRect(origin: .zero, size: previewFrame.size)
        )
        preview.contentView = canvas
        canvas.onTextRequested = { [weak self] point in
            self?.requestText(at: point)
        }
        previewWindow = preview
        canvasView = canvas

        toolbar.setFrameOrigin(
            PreviewLayout.toolbarOrigin(
                previewFrame: previewFrame,
                toolbarSize: toolbar.frame.size,
                visibleFrame: visibleFrame
            )
        )
        toolbarWindow = toolbar

        NSApp.activate(ignoringOtherApps: true)
        preview.makeKeyAndOrderFront(nil)
        preview.makeFirstResponder(canvas)
        preview.addChildWindow(toolbar, ordered: .above)
        toolbar.orderFrontRegardless()
        preview.makeKey()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            guard !self.isPresentingTextDialog else { return event }
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
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = level
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.acceptsMouseMovedEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }

    private func makeToolbar() -> NSPanel {
        let buttonWidth: CGFloat = 70
        let toolbarSize = CGSize(width: buttonWidth * 10 + 20, height: 48)
        let panel = makePanel(
            frame: CGRect(origin: .zero, size: toolbarSize),
            level: NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
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
        let text = makeButton(title: "Text", symbol: "textformat", action: #selector(selectText))
        text.setButtonType(.toggle)
        textButton = text
        stack.addArrangedSubview(text)
        let mosaic = makeButton(title: "Mosaic", symbol: "square.grid.3x3", action: #selector(selectMosaic))
        mosaic.setButtonType(.toggle)
        mosaicButton = mosaic
        stack.addArrangedSubview(mosaic)
        let ocr = makeButton(title: "OCR", symbol: "text.viewfinder", action: #selector(recognizeText))
        ocrButton = ocr
        stack.addArrangedSubview(ocr)
        let translate = makeButton(title: "Translate", symbol: "character.book.closed", action: #selector(translateText))
        translateButton = translate
        stack.addArrangedSubview(translate)
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

    private func targetScreen() -> NSScreen? {
        NSScreen.screens.max { left, right in
            let leftIntersection = left.frame.intersection(captureFrame)
            let rightIntersection = right.frame.intersection(captureFrame)
            return leftIntersection.width * leftIntersection.height
                < rightIntersection.width * rightIntersection.height
        } ?? NSScreen.main
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

    @objc private func selectText() {
        setActiveTool(canvasView?.activeTool == .text ? .none : .text)
    }

    @objc private func selectMosaic() {
        setActiveTool(canvasView?.activeTool == .mosaic ? .none : .mosaic)
    }

    @objc private func undo() {
        canvasView?.undo()
    }

    @objc private func recognizeText() {
        guard ocrButton?.isEnabled != false else { return }
        ocrButton?.isEnabled = false
        ocrButton?.title = "Reading…"

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let text = try await ocrService.recognizeText(in: image)
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
                ocrButton?.title = "Copied"
                ocrButton?.image = NSImage(
                    systemSymbolName: "checkmark",
                    accessibilityDescription: "OCR text copied"
                )
                ocrButton?.isEnabled = true
            } catch {
                ocrButton?.title = "OCR"
                ocrButton?.isEnabled = true
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = "Text recognition failed"
                alert.informativeText = error.localizedDescription
                alert.runModal()
            }
        }
    }

    @objc private func translateText() {
        guard translateButton?.isEnabled != false else { return }
        guard #available(macOS 26.0, *) else {
            showWarning(
                title: "Translation requires macOS 26",
                message: "OCR remains available on earlier macOS versions."
            )
            return
        }

        translateButton?.isEnabled = false
        translateButton?.title = "Translating…"

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let sourceText = try await ocrService.recognizeText(in: image)
                let translatedText = try await TranslationService().translate(sourceText)
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(translatedText, forType: .string)
                translateButton?.title = "Copied"
                translateButton?.image = NSImage(
                    systemSymbolName: "checkmark",
                    accessibilityDescription: "Translation copied"
                )
                translateButton?.isEnabled = true
            } catch {
                translateButton?.title = "Translate"
                translateButton?.isEnabled = true
                showWarning(
                    title: "Translation failed",
                    message: "\(error.localizedDescription)\n\nInstall the required languages in System Settings → General → Language & Region → Translation Languages, then try again."
                )
            }
        }
    }

    private func showWarning(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.runModal()
    }

    private func setActiveTool(_ tool: AnnotationTool) {
        canvasView?.activeTool = tool
        arrowButton?.state = tool == .arrow ? .on : .off
        rectangleButton?.state = tool == .rectangle ? .on : .off
        textButton?.state = tool == .text ? .on : .off
        mosaicButton?.state = tool == .mosaic ? .on : .off
    }

    private func requestText(at point: CGPoint) {
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.placeholderString = "Enter annotation text"

        let alert = NSAlert()
        alert.messageText = "Add text"
        alert.accessoryView = field
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field

        isPresentingTextDialog = true
        defer { isPresentingTextDialog = false }
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        canvasView?.addText(field.stringValue, at: point)
    }

    @objc private func cancel() {
        let callback = onClose
        finish()
        callback?()
    }

    private func finish() {
        if let previewWindow, let toolbarWindow {
            previewWindow.removeChildWindow(toolbarWindow)
        }
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
