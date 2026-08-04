import AppKit
import Carbon
import UniformTypeIdentifiers

private final class MenuShortcutHintView: NSView {
    private let onSelect: () -> Void

    init(title: String, shortcutHint: String, onSelect: @escaping () -> Void) {
        self.onSelect = onSelect
        super.init(frame: NSRect(x: 0, y: 0, width: 310, height: 22))

        let titleField = NSTextField(labelWithString: title)
        titleField.font = NSFont.menuFont(ofSize: 0)
        titleField.translatesAutoresizingMaskIntoConstraints = false

        let shortcutField = NSTextField(labelWithString: shortcutHint)
        shortcutField.font = NSFont.menuFont(ofSize: 0)
        shortcutField.textColor = .secondaryLabelColor
        shortcutField.alignment = .right
        shortcutField.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleField)
        addSubview(shortcutField)
        NSLayoutConstraint.activate([
            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            titleField.centerYAnchor.constraint(equalTo: centerYAnchor),
            shortcutField.leadingAnchor.constraint(greaterThanOrEqualTo: titleField.trailingAnchor, constant: 16),
            shortcutField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            shortcutField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point) else { return }
        enclosingMenuItem?.menu?.cancelTracking()
        onSelect()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let captureService = WindowCaptureService()
    private var windowHotKey: GlobalHotKey?
    private var portionHotKey: GlobalHotKey?
    private var fastCaptureMonitor: Any?
    private var overlayController: CaptureOverlayController?
    private var previewController: CapturePreviewController?
    private var isPreparingCapture = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "viewfinder",
            accessibilityDescription: "ohCapture"
        )

        let menu = NSMenu()
        let fastCaptureItem = menu.addItem(
            withTitle: "Fast Capture",
            action: nil,
            keyEquivalent: ""
        )
        fastCaptureItem.view = MenuShortcutHintView(
            title: "Fast Capture",
            shortcutHint: "⇧⌥ + Left Click"
        ) { [weak self] in
            self?.startAuthorizedCapture(mode: .region)
        }

        let windowItem = menu.addItem(
            withTitle: "Capture Selected Window",
            action: #selector(startWindowCaptureFromMenu),
            keyEquivalent: "1"
        )
        windowItem.keyEquivalentModifierMask = [.shift, .option]
        windowItem.target = self

        let portionItem = menu.addItem(
            withTitle: "Capture Selected Portion",
            action: #selector(startPortionCaptureFromMenu),
            keyEquivalent: "2"
        )
        portionItem.keyEquivalentModifierMask = [.shift, .option]
        portionItem.target = self

        menu.addItem(.separator())
        let quitItem = menu.addItem(
            withTitle: "Quit ohCapture",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: ""
        )
        quitItem.image = nil
        quitItem.target = NSApp
        item.menu = menu
        statusItem = item

        windowHotKey = GlobalHotKey(
            keyCode: UInt32(kVK_ANSI_1),
            modifiers: UInt32(optionKey | shiftKey),
            identifier: 1
        ) { [weak self] in
            self?.startAuthorizedCapture(mode: .window)
        }
        portionHotKey = GlobalHotKey(
            keyCode: UInt32(kVK_ANSI_2),
            modifiers: UInt32(optionKey | shiftKey),
            identifier: 2
        ) { [weak self] in
            self?.startAuthorizedCapture(mode: .region)
        }
        fastCaptureMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) {
            [weak self] event in
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            guard modifiers.contains([.shift, .option]),
                  !modifiers.contains([.command, .control]) else { return }
            self?.startFastCapture(at: NSEvent.mouseLocation)
        }
    }

    private func startAuthorizedCapture(mode: CaptureOverlayMode) {
        guard overlayController == nil, !isPreparingCapture else { return }
        isPreparingCapture = true

        Task { @MainActor in
            defer { isPreparingCapture = false }
            do {
                let windows = try await captureService.availableWindows(requestingDirectCaptureAccess: true).sorted {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
                guard mode != .window || !windows.isEmpty else {
                    showError("No capturable windows were found.")
                    return
                }
                beginOverlay(mode: mode, windows: windows)
            } catch WindowCaptureError.permissionRequired {
                showPermissionHelp()
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    private func startFastCapture(at initialMouseLocation: CGPoint) {
        guard overlayController == nil, !isPreparingCapture else { return }
        beginOverlay(mode: .region, windows: [], initialMouseLocation: initialMouseLocation)
    }

    private func beginOverlay(
        mode: CaptureOverlayMode,
        windows: [CapturableWindow],
        initialMouseLocation: CGPoint? = nil
    ) {
        let controller = CaptureOverlayController(windows: windows)
        overlayController = controller
        controller.begin(mode: mode, startingAt: initialMouseLocation) { [weak self] selection in
            guard let self else { return }
            self.overlayController = nil
            guard let selection else { return }

            Task { @MainActor in
                do {
                    switch selection {
                    case .window(let window):
                        let image = try await self.captureService.capture(window)
                        self.showPreview(
                            image,
                            frame: window.appKitFrame,
                            suggestedName: window.safeFilename
                        )
                    case .region(let region, let screen):
                        let image = try await self.captureService.captureRegion(region, on: screen)
                        self.showPreview(image, frame: region, suggestedName: "ohCapture-region")
                    }
                } catch WindowCaptureError.permissionRequired {
                    self.showPermissionHelp()
                } catch {
                    self.showError(error.localizedDescription)
                }
            }
        }
    }

    @objc private func startWindowCaptureFromMenu() {
        startAuthorizedCapture(mode: .window)
    }

    @objc private func startPortionCaptureFromMenu() {
        startAuthorizedCapture(mode: .region)
    }

    @MainActor
    private func showPreview(_ image: CGImage, frame: CGRect, suggestedName: String) {
        previewController?.close()

        let controller = CapturePreviewController(image: image, captureFrame: frame)
        previewController = controller
        controller.begin(
            onCopy: { [weak self] in
                self?.previewController = nil
            },
            onSave: { [weak self] image in
                guard let self else { return }
                self.previewController = nil
                do {
                    try self.save(image, suggestedName: suggestedName)
                } catch {
                    self.showError(error.localizedDescription)
                }
            },
            onClose: { [weak self] in
                self?.previewController = nil
            }
        )
    }

    @MainActor
    private func save(_ image: CGImage, suggestedName: String) throws {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(suggestedName).png"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try WindowCaptureService.writePNG(image, to: url)
    }

    @MainActor
    private func showPermissionHelp() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Screen Recording permission is required"
        alert.informativeText = "Allow ohCapture in System Settings → Privacy & Security → Screen & System Audio Recording, then relaunch the app."
        alert.runModal()
    }

    @MainActor
    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "ohCapture couldn’t capture the window"
        alert.informativeText = message
        alert.runModal()
    }

    deinit {
        if let fastCaptureMonitor { NSEvent.removeMonitor(fastCaptureMonitor) }
    }
}
