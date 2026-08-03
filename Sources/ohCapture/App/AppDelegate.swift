import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "viewfinder",
            accessibilityDescription: "ohCapture"
        )

        let menu = NSMenu()
        menu.addItem(
            withTitle: "Capture",
            action: #selector(startCapture),
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

    @objc private func startCapture() {
        // The first milestone replaces this placeholder with ScreenCaptureKit.
        NSSound.beep()
    }
}

