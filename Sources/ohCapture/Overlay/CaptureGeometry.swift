import CoreGraphics

enum CaptureGeometry {
    static func appKitWindowFrame(
        from screenCaptureFrame: CGRect,
        mainDisplayMaxY: CGFloat
    ) -> CGRect {
        CGRect(
            x: screenCaptureFrame.minX,
            y: mainDisplayMaxY - screenCaptureFrame.maxY,
            width: screenCaptureFrame.width,
            height: screenCaptureFrame.height
        )
    }

    static func normalizedRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    static func globalRegion(localRegion: CGRect, screenFrame: CGRect) -> CGRect {
        localRegion.offsetBy(dx: screenFrame.minX, dy: screenFrame.minY)
    }
}
