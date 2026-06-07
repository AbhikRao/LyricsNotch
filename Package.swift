// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "LyricsNotch",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LyricsNotch", targets: ["LyricsNotch"]),
        .executable(name: "LyricsNotchChecks", targets: ["LyricsNotchChecks"])
    ],
    targets: [
        .target(
            name: "LyricsNotchCore",
            path: "Sources/LyricsNotchCore"
        ),
        .executableTarget(
            name: "LyricsNotch",
            dependencies: ["LyricsNotchCore"],
            path: "Sources/LyricsNotchApp"
        ),
        .executableTarget(
            name: "LyricsNotchChecks",
            dependencies: ["LyricsNotchCore"],
            path: "Sources/LyricsNotchChecks"
        )
    ]
)
