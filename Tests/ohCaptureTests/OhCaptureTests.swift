import XCTest
@testable import ohCapture

final class OhCaptureTests: XCTestCase {
    func testPreviewAndToolbarStayInsideVisibleScreen() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let oversizedCapture = CGRect(x: -200, y: -100, width: 2200, height: 1300)
        let preview = PreviewLayout.fittedPreviewFrame(
            captureFrame: oversizedCapture,
            visibleFrame: screen
        )
        let toolbarSize = CGSize(width: 720, height: 48)
        let toolbarOrigin = PreviewLayout.toolbarOrigin(
            previewFrame: preview,
            toolbarSize: toolbarSize,
            visibleFrame: screen
        )
        let toolbar = CGRect(origin: toolbarOrigin, size: toolbarSize)

        XCTAssertTrue(screen.contains(preview))
        XCTAssertTrue(screen.contains(toolbar))
    }

    func testToolbarFallsBackInsidePreviewWhenNoOutsideSpaceExists() {
        let screen = CGRect(x: 0, y: 0, width: 1280, height: 720)
        let preview = CGRect(x: 64, y: 0, width: 1152, height: 720)
        let toolbarSize = CGSize(width: 720, height: 48)
        let origin = PreviewLayout.toolbarOrigin(
            previewFrame: preview,
            toolbarSize: toolbarSize,
            visibleFrame: screen
        )

        XCTAssertGreaterThanOrEqual(origin.y, screen.minY)
        XCTAssertLessThanOrEqual(origin.y + toolbarSize.height, screen.maxY)
    }

    func testFreeRegionNormalizesEveryDragDirection() {
        let expected = CGRect(x: 120, y: 80, width: 300, height: 200)
        XCTAssertEqual(
            CaptureGeometry.normalizedRect(
                from: CGPoint(x: 120, y: 80),
                to: CGPoint(x: 420, y: 280)
            ),
            expected
        )
        XCTAssertEqual(
            CaptureGeometry.normalizedRect(
                from: CGPoint(x: 420, y: 280),
                to: CGPoint(x: 120, y: 80)
            ),
            expected
        )
    }

    func testFreeRegionConvertsToSecondaryDisplayCoordinates() {
        let local = CGRect(x: 40, y: 60, width: 500, height: 300)
        let secondaryScreen = CGRect(x: -1920, y: 200, width: 1920, height: 1080)
        XCTAssertEqual(
            CaptureGeometry.globalRegion(localRegion: local, screenFrame: secondaryScreen),
            CGRect(x: -1880, y: 260, width: 500, height: 300)
        )
    }

    func testScreenCaptureWindowFrameUsesMainDisplayCoordinateSystem() {
        let screenCaptureFrame = CGRect(x: 100, y: -800, width: 900, height: 700)
        XCTAssertEqual(
            CaptureGeometry.appKitWindowFrame(
                from: screenCaptureFrame,
                mainDisplayMaxY: 900
            ),
            CGRect(x: 100, y: 1000, width: 900, height: 700)
        )
    }

    func testRenderedImageFillsTheOriginalPixelCanvas() throws {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: 80,
            height: 40,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return XCTFail("Could not create source image context")
        }
        context.setFillColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 80, height: 40))
        let source = try XCTUnwrap(context.makeImage())
        let canvas = AnnotationCanvasView(
            image: source,
            frame: CGRect(x: 0, y: 0, width: 20, height: 10)
        )
        let rendered = try XCTUnwrap(canvas.renderedImage())

        XCTAssertEqual(rendered.width, 80)
        XCTAssertEqual(rendered.height, 40)
        let providerData = try XCTUnwrap(rendered.dataProvider?.data)
        let bytes = CFDataGetBytePtr(providerData)
        let topRightOffset = (rendered.height - 1) * rendered.bytesPerRow + (rendered.width - 1) * 4
        XCTAssertGreaterThan(bytes?[topRightOffset] ?? 0, 200)
        XCTAssertLessThan(bytes?[topRightOffset + 1] ?? 255, 80)
        XCTAssertEqual(bytes?[topRightOffset + 3], 255)
    }
}
