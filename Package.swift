// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Pullshot",
    defaultLocalization: "ko",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(name: "PullshotKit", targets: ["PullshotKit"]),
        .executable(name: "pullshot", targets: ["pullshot"]),
        .executable(name: "PullshotApp", targets: ["PullshotApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.8.0"),
    ],
    targets: [
        .target(name: "PullshotKit"),
        .executableTarget(
            name: "pullshot",
            dependencies: [
                "PullshotKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .executableTarget(name: "PullshotApp", dependencies: ["PullshotKit"]),
        .testTarget(name: "PullshotKitTests", dependencies: ["PullshotKit"]),
        .testTarget(name: "PullshotCLITests", dependencies: ["pullshot", "PullshotKit"]),
        .testTarget(name: "PullshotAppTests", dependencies: ["PullshotApp", "PullshotKit"]),
    ]
)
