import AppKit

enum AnnotationTool {
    case none
    case arrow
    case rectangle
}

private struct ShapeAnnotation {
    let tool: AnnotationTool
    let start: CGPoint
    let end: CGPoint
}

final class AnnotationCanvasView: NSView {
    var activeTool: AnnotationTool = .none

    private let sourceImage: CGImage
    private var annotations: [ShapeAnnotation] = []
    private var draft: ShapeAnnotation?

    init(image: CGImage, frame: CGRect) {
        sourceImage = image
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard activeTool != .none else { return }
        let point = clamped(event.locationInWindow)
        draft = ShapeAnnotation(tool: activeTool, start: point, end: point)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let draft else { return }
        self.draft = ShapeAnnotation(
            tool: draft.tool,
            start: draft.start,
            end: clamped(event.locationInWindow)
        )
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let draft else { return }
        let completed = ShapeAnnotation(
            tool: draft.tool,
            start: draft.start,
            end: clamped(event.locationInWindow)
        )
        self.draft = nil

        let distance = hypot(completed.end.x - completed.start.x, completed.end.y - completed.start.y)
        if distance >= 3 { annotations.append(completed) }
        needsDisplay = true
    }

    func undo() {
        if !annotations.isEmpty { annotations.removeLast() }
        needsDisplay = true
    }

    func renderedImage() -> CGImage? {
        guard bounds.width > 0, bounds.height > 0,
              let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: sourceImage.width,
                pixelsHigh: sourceImage.height,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
              ),
              let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return nil
        }

        bitmap.size = bounds.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphicsContext
        draw(bounds)
        graphicsContext.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.cgImage
    }

    override func draw(_ dirtyRect: NSRect) {
        NSImage(cgImage: sourceImage, size: bounds.size).draw(
            in: bounds,
            from: .zero,
            operation: .copy,
            fraction: 1
        )

        annotations.forEach(drawAnnotation)
        if let draft { drawAnnotation(draft) }
    }

    private func drawAnnotation(_ annotation: ShapeAnnotation) {
        NSColor.systemRed.setStroke()
        NSColor.systemRed.setFill()

        switch annotation.tool {
        case .arrow:
            drawArrow(from: annotation.start, to: annotation.end)
        case .rectangle:
            let rect = normalizedRect(from: annotation.start, to: annotation.end)
            let path = NSBezierPath(rect: rect)
            path.lineWidth = 3
            path.stroke()
        case .none:
            break
        }
    }

    private func drawArrow(from start: CGPoint, to end: CGPoint) {
        let line = NSBezierPath()
        line.move(to: start)
        line.line(to: end)
        line.lineWidth = 3
        line.lineCapStyle = .round
        line.stroke()

        let angle = atan2(end.y - start.y, end.x - start.x)
        let headLength: CGFloat = 14
        let wingAngle: CGFloat = .pi / 7
        let left = CGPoint(
            x: end.x - headLength * cos(angle - wingAngle),
            y: end.y - headLength * sin(angle - wingAngle)
        )
        let right = CGPoint(
            x: end.x - headLength * cos(angle + wingAngle),
            y: end.y - headLength * sin(angle + wingAngle)
        )
        let head = NSBezierPath()
        head.move(to: end)
        head.line(to: left)
        head.line(to: right)
        head.close()
        head.fill()
    }

    private func normalizedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    private func clamped(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, bounds.minX), bounds.maxX),
            y: min(max(point.y, bounds.minY), bounds.maxY)
        )
    }
}
