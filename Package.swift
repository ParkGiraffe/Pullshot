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
        .testTarget(name: "PullshotKitTests", dependencies: ["PullshotKit"]),
        .testTarget(name: "PullshotCLITests", dependencies: ["pullshot", "PullshotKit"]),
    ]
)
