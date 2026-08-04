import AppKit

final class CaptureOverlayView: NSView {
    var screenFrame: CGRect = .zero
    weak var screen: NSScreen?
    var mode: CaptureOverlayMode = .region
    var windows: [CapturableWindow] = []
    var onSelection: ((CaptureSelection) -> Void)?

    private var hoveredWindow: CapturableWindow? {
        didSet { needsDisplay = true }
    }
    private var trackingAreaReference: NSTrackingArea?
    private var dragStart: CGPoint?
    private var pressedWindow: CapturableWindow?
    private var selectionRect: CGRect?

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaReference { removeTrackingArea(trackingAreaReference) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingAreaReference = area
    }

    override func mouseMoved(with event: NSEvent) {
        guard mode == .window else { return }
        updateHoveredWindow(
            atScreenPoint: CGPoint(
            x: screenFrame.minX + event.locationInWindow.x,
            y: screenFrame.minY + event.locationInWindow.y
            )
        )
    }

    func updateHoveredWindow(atScreenPoint point: CGPoint) {
        guard mode == .window else { return }
        hoveredWindow = windows.first { $0.appKitFrame.contains(point) }
    }

    override func mouseDown(with event: NSEvent) {
        if mode == .window {
            pressedWindow = hoveredWindow
            return
        }
        dragStart = pointClampedToBounds(event.locationInWindow)
        selectionRect = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard mode == .region else { return }
        guard let dragStart else { return }
        let current = pointClampedToBounds(event.locationInWindow)
        let rect = CaptureGeometry.normalizedRect(from: dragStart, to: current)
        guard hypot(rect.width, rect.height) >= 3 else { return }
        selectionRect = rect
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if mode == .window {
            defer { pressedWindow = nil }
            if let pressedWindow { onSelection?(.window(pressedWindow)) }
            return
        }
        defer {
            dragStart = nil
            selectionRect = nil
        }

        if let selectionRect, selectionRect.width >= 4, selectionRect.height >= 4, let screen {
            let globalRegion = CaptureGeometry.globalRegion(
                localRegion: selectionRect,
                screenFrame: screenFrame
            )
            onSelection?(.region(globalRegion, screen))
        }
    }

    func beginSelection(atScreenPoint point: CGPoint) {
        dragStart = localPoint(fromScreenPoint: point)
        selectionRect = nil
        needsDisplay = true
    }

    func updateSelection(atScreenPoint point: CGPoint) {
        guard let dragStart else { return }
        let current = localPoint(fromScreenPoint: point)
        selectionRect = CaptureGeometry.normalizedRect(from: dragStart, to: current)
        needsDisplay = true
    }

    func endSelection(atScreenPoint point: CGPoint) {
        updateSelection(atScreenPoint: point)
        defer {
            dragStart = nil
            selectionRect = nil
        }
        guard let selectionRect,
              selectionRect.width >= 4,
              selectionRect.height >= 4,
              let screen else { return }
        let globalRegion = CaptureGeometry.globalRegion(
            localRegion: selectionRect,
            screenFrame: screenFrame
        )
        onSelection?(.region(globalRegion, screen))
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.32).setFill()
        bounds.fill()

        if let selectionRect {
            drawSelection(selectionRect)
            return
        }

        guard mode == .window, let hoveredWindow else { return }
        let localFrame = hoveredWindow.appKitFrame.offsetBy(
            dx: -screenFrame.minX,
            dy: -screenFrame.minY
        )

        NSGraphicsContext.saveGraphicsState()
        NSColor.clear.setFill()
        localFrame.fill(using: .copy)
        NSGraphicsContext.restoreGraphicsState()

        let border = NSBezierPath(
            roundedRect: localFrame.insetBy(dx: 1, dy: 1),
            xRadius: 6,
            yRadius: 6
        )
        border.lineWidth = 2
        NSColor.systemBlue.setStroke()
        border.stroke()
        drawLabel(hoveredWindow.displayName, above: localFrame)

    }

    private func drawSelection(_ rect: CGRect) {
        NSGraphicsContext.saveGraphicsState()
        NSColor.clear.setFill()
        rect.fill(using: .copy)
        NSGraphicsContext.restoreGraphicsState()

        let border = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1
        NSColor.white.setStroke()
        border.stroke()

        let dimensions = "\(Int(rect.width)) × \(Int(rect.height))"
        drawLabel(dimensions, above: rect)
    }

    private func pointClampedToBounds(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }

    private func localPoint(fromScreenPoint point: CGPoint) -> CGPoint {
        pointClampedToBounds(
            CGPoint(x: point.x - screenFrame.minX, y: point.y - screenFrame.minY)
        )
    }

    private func drawLabel(_ text: String, above frame: CGRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributed.size()
        let labelFrame = CGRect(
            x: frame.minX,
            y: min(bounds.maxY - textSize.height - 12, frame.maxY + 8),
            width: min(textSize.width + 18, bounds.width),
            height: textSize.height + 8
        )
        let background = NSBezierPath(roundedRect: labelFrame, xRadius: 5, yRadius: 5)
        NSColor.systemBlue.setFill()
        background.fill()
        attributed.draw(at: CGPoint(x: labelFrame.minX + 9, y: labelFrame.minY + 4))
    }
}
