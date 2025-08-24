// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AudioCapService",
    platforms: [
        .macOS("14.4")
    ],
    products: [
        .library(
            name: "AudioCapService",
            targets: ["AudioCapService"]
        ),
    ],
    targets: [
        .target(
            name: "AudioCapService",
            dependencies: [],
            path: "Sources/AudioCapService"
        ),
        .testTarget(
            name: "AudioCapServiceTests",
            dependencies: ["AudioCapService"]
        ),
    ]
)