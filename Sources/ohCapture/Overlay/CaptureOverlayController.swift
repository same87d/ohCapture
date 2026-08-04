import AppKit
import Carbon

private final class CaptureOverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

enum CaptureSelection {
    case window(CapturableWindow)
    case region(CGRect, NSScreen)
}

enum CaptureOverlayMode: Equatable {
    case window
    case region
}

final class CaptureOverlayController {
    private let windows: [CapturableWindow]
    private var overlayWindows: [NSWindow] = []
    private var completion: ((CaptureSelection?) -> Void)?
    private var escapeMonitor: Any?
    private var fastDragMonitor: Any?
    private weak var fastSelectionView: CaptureOverlayView?

    init(windows: [CapturableWindow]) {
        self.windows = windows
    }

    func begin(
        mode: CaptureOverlayMode,
        startingAt initialMouseLocation: CGPoint? = nil,
        completion: @escaping (CaptureSelection?) -> Void
    ) {
        self.completion = completion

        NSApp.activate(ignoringOtherApps: true)
        overlayWindows = NSScreen.screens.map { screen in
            let overlay = CaptureOverlayWindow(
                contentRect: screen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            overlay.level = .screenSaver
            overlay.backgroundColor = .clear
            overlay.isOpaque = false
            overlay.hasShadow = false
            overlay.ignoresMouseEvents = false
            overlay.acceptsMouseMovedEvents = true
            overlay.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let view = CaptureOverlayView(frame: NSRect(origin: .zero, size: screen.frame.size))
            view.screenFrame = screen.frame
            view.screen = screen
            view.mode = mode
            view.windows = windows
            view.onSelection = { [weak self] selection in self?.finish(with: selection) }
            overlay.contentView = view
            overlay.orderFrontRegardless()
            return overlay
        }

        let mouseLocation = NSEvent.mouseLocation
        if let activeOverlay = overlayWindows.first(where: { $0.frame.contains(mouseLocation) }) {
            activeOverlay.makeKey()
            activeOverlay.makeFirstResponder(activeOverlay.contentView)
            if mode == .window,
               let view = activeOverlay.contentView as? CaptureOverlayView {
                view.updateHoveredWindow(atScreenPoint: mouseLocation)
            }
        }

        if mode == .region,
           let initialMouseLocation,
           let overlay = overlayWindows.first(where: { $0.frame.contains(initialMouseLocation) }),
           let view = overlay.contentView as? CaptureOverlayView {
            fastSelectionView = view
            view.beginSelection(atScreenPoint: initialMouseLocation)
            fastDragMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDragged, .leftMouseUp]
            ) { [weak self] event in
                guard let self, let fastSelectionView else { return }
                let location = NSEvent.mouseLocation
                if event.type == .leftMouseUp {
                    fastSelectionView.endSelection(atScreenPoint: location)
                } else {
                    fastSelectionView.updateSelection(atScreenPoint: location)
                }
            }
        }

        NSCursor.crosshair.push()
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == UInt16(kVK_Escape) {
                self?.finish(with: nil)
                return nil
            }
            return event
        }
    }

    private func finish(with selection: CaptureSelection?) {
        guard let completion else { return }
        self.completion = nil
        overlayWindows.forEach { $0.orderOut(nil) }
        overlayWindows.removeAll()
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
        escapeMonitor = nil
        if let fastDragMonitor { NSEvent.removeMonitor(fastDragMonitor) }
        fastDragMonitor = nil
        fastSelectionView = nil
        NSCursor.pop()
        completion(selection)
    }

    deinit {
        if completion != nil { finish(with: nil) }
    }
}
