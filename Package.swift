// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Pigeonhole",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "PigeonholeCore",
            path: "Sources/PigeonholeCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "Pigeonhole",
            dependencies: ["PigeonholeCore"],
            path: "Sources/Pigeonhole",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // An executable rather than a test target: the Command Line Tools
        // ship neither XCTest nor swift-testing, and Xcode isn't installed.
        .executableTarget(
            name: "PigeonholeChecks",
            dependencies: ["PigeonholeCore"],
            path: "Sources/PigeonholeChecks",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Renders the README screenshots from sample data, so they never
        // show anyone's real PRs.
        .executableTarget(
            name: "PigeonholeSnapshots",
            dependencies: ["PigeonholeCore"],
            path: "Sources/PigeonholeSnapshots",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
