import CoreGraphics

enum PreviewLayout {
    static func fittedPreviewFrame(captureFrame: CGRect, visibleFrame: CGRect) -> CGRect {
        guard captureFrame.width > 0, captureFrame.height > 0 else {
            return CGRect(
                x: visibleFrame.midX - 200,
                y: visibleFrame.midY - 150,
                width: 400,
                height: 300
            )
        }

        let maximumSize = CGSize(
            width: max(1, visibleFrame.width * 0.9),
            height: max(1, visibleFrame.height * 0.8)
        )
        let scale = min(
            1,
            maximumSize.width / captureFrame.width,
            maximumSize.height / captureFrame.height
        )
        let size = CGSize(
            width: captureFrame.width * scale,
            height: captureFrame.height * scale
        )
        let proposedOrigin = CGPoint(
            x: captureFrame.midX - size.width / 2,
            y: captureFrame.midY - size.height / 2
        )
        return CGRect(
            x: clamp(proposedOrigin.x, minimum: visibleFrame.minX, maximum: visibleFrame.maxX - size.width),
            y: clamp(proposedOrigin.y, minimum: visibleFrame.minY, maximum: visibleFrame.maxY - size.height),
            width: size.width,
            height: size.height
        )
    }

    static func toolbarOrigin(
        previewFrame: CGRect,
        toolbarSize: CGSize,
        visibleFrame: CGRect
    ) -> CGPoint {
        let x = clamp(
            previewFrame.maxX - toolbarSize.width,
            minimum: visibleFrame.minX,
            maximum: visibleFrame.maxX - toolbarSize.width
        )
        let belowY = previewFrame.minY - toolbarSize.height - 8
        if belowY >= visibleFrame.minY {
            return CGPoint(x: x, y: belowY)
        }

        let aboveY = previewFrame.maxY + 8
        if aboveY + toolbarSize.height <= visibleFrame.maxY {
            return CGPoint(x: x, y: aboveY)
        }

        return CGPoint(
            x: x,
            y: clamp(
                previewFrame.minY + 8,
                minimum: visibleFrame.minY,
                maximum: visibleFrame.maxY - toolbarSize.height
            )
        )
    }

    private static func clamp(_ value: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        guard maximum >= minimum else { return minimum }
        return min(max(value, minimum), maximum)
    }
}
