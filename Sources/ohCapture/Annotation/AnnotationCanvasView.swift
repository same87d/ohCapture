import AppKit
import CoreImage

enum AnnotationTool {
    case none
    case arrow
    case rectangle
    case text
    case mosaic
}

private struct ShapeAnnotation {
    let tool: AnnotationTool
    let start: CGPoint
    let end: CGPoint
}

private enum Annotation {
    case shape(ShapeAnnotation)
    case text(String, CGPoint)
    case mosaic(CGRect)
}

final class AnnotationCanvasView: NSView {
    var activeTool: AnnotationTool = .none
    var onTextRequested: ((CGPoint) -> Void)?

    private let sourceImage: CGImage
    private let displayImage: NSImage
    private let mosaicImage: NSImage
    private var annotations: [Annotation] = []
    private var draft: ShapeAnnotation?

    init(image: CGImage, frame: CGRect) {
        sourceImage = image
        displayImage = NSImage(cgImage: image, size: frame.size)
        mosaicImage = AnnotationCanvasView.makeMosaicImage(from: image, size: frame.size)
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

        if activeTool == .text {
            onTextRequested?(point)
            return
        }
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
        if distance >= 3 {
            if completed.tool == .mosaic {
                annotations.append(.mosaic(normalizedRect(from: completed.start, to: completed.end)))
            } else {
                annotations.append(.shape(completed))
            }
        }
        needsDisplay = true
    }

    func addText(_ text: String, at point: CGPoint) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        annotations.append(.text(trimmed, point))
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
        displayImage.draw(
            in: bounds,
            from: .zero,
            operation: .copy,
            fraction: 1
        )

        annotations.forEach(drawAnnotation)
        if let draft {
            if draft.tool == .mosaic {
                drawMosaic(in: normalizedRect(from: draft.start, to: draft.end))
            } else {
                drawShape(draft)
            }
        }
    }

    private func drawAnnotation(_ annotation: Annotation) {
        switch annotation {
        case .shape(let shape):
            drawShape(shape)
        case .text(let text, let point):
            drawText(text, at: point)
        case .mosaic(let rect):
            drawMosaic(in: rect)
        }
    }

    private func drawShape(_ annotation: ShapeAnnotation) {
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
        case .none, .text, .mosaic:
            break
        }
    }

    private func drawText(_ text: String, at point: CGPoint) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
            .foregroundColor: NSColor.systemRed,
            .strokeColor: NSColor.white,
            .strokeWidth: -2
        ]
        NSAttributedString(string: text, attributes: attributes).draw(at: point)
    }

    private func drawMosaic(in rect: CGRect) {
        guard rect.width > 0, rect.height > 0 else { return }
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: rect).addClip()
        NSGraphicsContext.current?.imageInterpolation = .none
        mosaicImage.draw(in: bounds, from: .zero, operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
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

    private static func makeMosaicImage(from image: CGImage, size: CGSize) -> NSImage {
        let input = CIImage(cgImage: image)
        let pixelScale = max(10, CGFloat(image.width) / max(size.width, 1) * 10)
        let output = input.applyingFilter(
            "CIPixellate",
            parameters: [kCIInputScaleKey: pixelScale]
        )
        let context = CIContext(options: [.cacheIntermediates: true])
        guard let rendered = context.createCGImage(output, from: input.extent) else {
            return NSImage(cgImage: image, size: size)
        }
        return NSImage(cgImage: rendered, size: size)
    }
}
