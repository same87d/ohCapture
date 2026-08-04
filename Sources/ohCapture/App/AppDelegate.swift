import AppKit
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let captureService = WindowCaptureService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "viewfinder",
            accessibilityDescription: "ohCapture"
        )

        let menu = NSMenu()
        menu.addItem(
            withTitle: "Capture Window…",
            action: #selector(chooseWindow),
            keyEquivalent: ""
        )
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit ohCapture",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        item.menu = menu
        statusItem = item
    }

    @objc private func chooseWindow() {
        Task { @MainActor in
            do {
                let windows = try await captureService.availableWindows()
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
