// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "media-pause",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "media-pause", targets: ["media-pause"]),
        .executable(name: "media-pause-tests", targets: ["media-pause-tests"])
    ],
    targets: [
        .target(name: "MediaPauseCore", path: "Sources/MediaPauseCore"),
        .executableTarget(name: "media-pause", dependencies: ["MediaPauseCore"], path: "Sources/media-pause"),
        .executableTarget(name: "media-pause-tests", dependencies: ["MediaPauseCore"], path: "Tests/MediaPauseCoreTests")
    ]
)
