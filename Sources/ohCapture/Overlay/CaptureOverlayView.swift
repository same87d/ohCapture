import AppKit

final class CaptureOverlayView: NSView {
    var screenFrame: CGRect = .zero
    var windows: [CapturableWindow] = []
    var onSelection: ((CapturableWindow) -> Void)?

    private var hoveredWindow: CapturableWindow? {
        didSet { needsDisplay = true }
    }
    private var trackingAreaReference: NSTrackingArea?

    override var acceptsFirstResponder: Bool { true }

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
        let pointInScreen = CGPoint(
            x: screenFrame.minX + event.locationInWindow.x,
            y: screenFrame.minY + event.locationInWindow.y
        )
        hoveredWindow = windows.first { $0.appKitFrame.contains(pointInScreen) }
    }

    override func mouseDown(with event: NSEvent) {
        if let hoveredWindow { onSelection?(hoveredWindow) }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.32).setFill()
        bounds.fill()

        guard let hoveredWindow else { return }
        let localFrame = hoveredWindow.appKitFrame.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY)

        NSGraphicsContext.saveGraphicsState()
        NSColor.clear.setFill()
        localFrame.fill(using: .copy)
        NSGraphicsContext.restoreGraphicsState()

        let border = NSBezierPath(roundedRect: localFrame.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
        border.lineWidth = 2
        NSColor.systemBlue.setStroke()
        border.stroke()

        drawLabel(hoveredWindow.displayName, above: localFrame)
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
