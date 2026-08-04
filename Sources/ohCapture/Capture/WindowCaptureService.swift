import AppKit
import CoreGraphics
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers

enum WindowCaptureError: LocalizedError {
    case permissionRequired
    case invalidWindowSize
    case pngDestinationUnavailable
    case pngEncodingFailed

    var errorDescription: String? {
        switch self {
        case .permissionRequired:
            return "Screen Recording permission is required."
        case .invalidWindowSize:
            return "The selected window has an invalid size."
        case .pngDestinationUnavailable:
            return "A PNG destination could not be created."
        case .pngEncodingFailed:
            return "The screenshot could not be encoded as PNG."
        }
    }
}

struct CapturableWindow: Identifiable {
    let window: SCWindow

    var id: CGWindowID { window.windowID }

    var displayName: String {
        let application = window.owningApplication?.applicationName ?? "Unknown application"
        let title = window.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? application : "\(application) — \(title)"
    }

    var safeFilename: String {
        let invalidCharacters = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = displayName
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "ohCapture" : String(cleaned.prefix(100))
    }

    var appKitFrame: CGRect {
        let mainDisplayMaxY = NSScreen.screens.first?.frame.maxY ?? 0
        return CaptureGeometry.appKitWindowFrame(
            from: window.frame,
            mainDisplayMaxY: mainDisplayMaxY
        )
    }
}

final class WindowCaptureService {
    func availableWindows(requestingDirectCaptureAccess: Bool = false) async throws -> [CapturableWindow] {
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            throw WindowCaptureError.permissionRequired
        }

        let content = try await SCShareableContent.excludingDesktopWindows(
            true,
            onScreenWindowsOnly: true
        )
        if requestingDirectCaptureAccess {
            try await requestDirectCaptureAccess(using: content)
        }
        let ownBundleIdentifier = Bundle.main.bundleIdentifier

        return content.windows
            .filter { window in
                guard window.isOnScreen,
                      window.frame.width >= 80,
                      window.frame.height >= 60,
                      window.windowLayer == 0 else {
                    return false
                }
                return window.owningApplication?.bundleIdentifier != ownBundleIdentifier
            }
            .map(CapturableWindow.init)
    }

    /// Completes macOS direct-capture authorization before the app displays
    /// its own selection interface. The 1 x 1 result is immediately discarded.
    private func requestDirectCaptureAccess(using content: SCShareableContent) async throws {
        guard let display = content.displays.first else {
            throw WindowCaptureError.invalidWindowSize
        }

        let ownBundleIdentifier = Bundle.main.bundleIdentifier
        let excludedApplications = content.applications.filter {
            $0.bundleIdentifier == ownBundleIdentifier
        }
        let filter = SCContentFilter(
            display: display,
            excludingApplications: excludedApplications,
            exceptingWindows: []
        )
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = CGRect(x: 0, y: 0, width: 1, height: 1)
        configuration.width = 1
        configuration.height = 1
        configuration.showsCursor = false

        _ = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
    }

    func capture(_ candidate: CapturableWindow) async throws -> CGImage {
        let frame = candidate.window.frame
        guard frame.width > 0, frame.height > 0 else {
            throw WindowCaptureError.invalidWindowSize
        }

        let scale = backingScaleFactor(for: frame)
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(frame.width * scale))
        configuration.height = max(1, Int(frame.height * scale))
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = false

        let filter = SCContentFilter(desktopIndependentWindow: candidate.window)
        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
    }

    func captureRegion(_ region: CGRect, on screen: NSScreen) async throws -> CGImage {
        guard region.width > 0, region.height > 0 else {
            throw WindowCaptureError.invalidWindowSize
        }

        guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            throw WindowCaptureError.invalidWindowSize
        }

        let content = try await SCShareableContent.excludingDesktopWindows(
            true,
            onScreenWindowsOnly: true
        )
        guard let display = content.displays.first(where: { $0.displayID == screenNumber.uint32Value }) else {
            throw WindowCaptureError.invalidWindowSize
        }

        let ownBundleIdentifier = Bundle.main.bundleIdentifier
        let excludedApplications = content.applications.filter {
            $0.bundleIdentifier == ownBundleIdentifier
        }
        let filter = SCContentFilter(
            display: display,
            excludingApplications: excludedApplications,
            exceptingWindows: []
        )

        let localRegion = CGRect(
            x: region.minX - screen.frame.minX,
            y: screen.frame.maxY - region.maxY,
            width: region.width,
            height: region.height
        )
        let scale = screen.backingScaleFactor
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = localRegion
        configuration.width = max(1, Int(localRegion.width * scale))
        configuration.height = max(1, Int(localRegion.height * scale))
        configuration.showsCursor = false

        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw WindowCaptureError.pngDestinationUnavailable
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw WindowCaptureError.pngEncodingFailed
        }
    }

    private func backingScaleFactor(for windowFrame: CGRect) -> CGFloat {
        NSScreen.screens
            .first(where: { $0.frame.intersects(windowFrame) })?
            .backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }
}
