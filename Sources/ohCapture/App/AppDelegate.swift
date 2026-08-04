import AppKit
import Carbon
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let captureService = WindowCaptureService()
    private var globalHotKey: GlobalHotKey?
    private var overlayController: CaptureOverlayController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "viewfinder",
            accessibilityDescription: "ohCapture"
        )

        let menu = NSMenu()
        let captureItem = menu.addItem(
            withTitle: "Capture Window…",
            action: #selector(chooseWindow),
            keyEquivalent: ""
        )
        captureItem.target = self

        let interactiveItem = menu.addItem(
            withTitle: "Interactive Capture    ⌥⇧2",
            action: #selector(startInteractiveCaptureFromMenu),
            keyEquivalent: ""
        )
        interactiveItem.target = self
        menu.addItem(.separator())
        let quitItem = menu.addItem(
            withTitle: "Quit ohCapture",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = NSApp
        item.menu = menu
        statusItem = item

        globalHotKey = GlobalHotKey(keyCode: UInt32(kVK_ANSI_2), modifiers: UInt32(optionKey | shiftKey)) { [weak self] in
            self?.startInteractiveCapture()
        }
    }

    @objc private func chooseWindow() {
        Task { @MainActor in
            do {
                let windows = try await captureService.availableWindows().sorted {
                    $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
                guard !windows.isEmpty else {
                    showError("No capturable windows were found.")
                    return
                }

                let picker = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 420, height: 28))
                windows.forEach { picker.addItem(withTitle: $0.displayName) }

                let alert = NSAlert()
                alert.messageText = "Capture a window"
                alert.informativeText = "The selected window is captured directly without moving it to the front."
                alert.accessoryView = picker
                alert.addButton(withTitle: "Capture")
                alert.addButton(withTitle: "Cancel")

                guard alert.runModal() == .alertFirstButtonReturn else { return }
                let window = windows[picker.indexOfSelectedItem]
                let image = try await captureService.capture(window)
                try save(image, suggestedName: window.safeFilename)
            } catch WindowCaptureError.permissionRequired {
                showPermissionHelp()
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    private func startInteractiveCapture() {
        guard overlayController == nil else { return }

        Task { @MainActor in
            do {
                let windows = try await captureService.availableWindows()
                guard !windows.isEmpty else {
                    showError("No capturable windows were found.")
                    return
                }

                let controller = CaptureOverlayController(windows: windows)
                overlayController = controller
                controller.begin { [weak self] selection in
                    guard let self else { return }
                    self.overlayController = nil
                    guard let selection else { return }

                    Task { @MainActor in
                        do {
                            switch selection {
                            case .window(let window):
                                let image = try await self.captureService.capture(window)
                                try self.save(image, suggestedName: window.safeFilename)
                            case .region(let region, let screen):
                                let image = try await self.captureService.captureRegion(region, on: screen)
                                try self.save(image, suggestedName: "ohCapture-region")
                            }
                        } catch {
                            self.showError(error.localizedDescription)
                        }
                    }
                }
            } catch WindowCaptureError.permissionRequired {
                showPermissionHelp()
            } catch {
                showError(error.localizedDescription)
            }
        }
    }

    @objc private func startInteractiveCaptureFromMenu() {
        startInteractiveCapture()
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
}
