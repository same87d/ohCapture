// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ohCapture",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "ohCapture", targets: ["ohCapture"])
    ],
    targets: [
        .executableTarget(
            name: "ohCapture",
            path: "Sources/ohCapture"
        ),
        .testTarget(
            name: "ohCaptureTests",
            dependencies: ["ohCapture"],
            path: "Tests/ohCaptureTests"
        )
    ]
)

