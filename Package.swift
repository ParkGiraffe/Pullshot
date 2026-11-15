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
    ],
    targets: [
        .target(name: "PullshotKit"),
        .testTarget(name: "PullshotKitTests", dependencies: ["PullshotKit"]),
    ]
)
