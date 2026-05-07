// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WeReadAudiobook",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "WeReadAudiobook",
            path: "Sources/WeReadAudiobook",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("CoreGraphics"),
            ]
        )
    ]
)
