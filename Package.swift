// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MScreenshot",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MScreenshot",
            path: "Sources/MScreenshot",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
