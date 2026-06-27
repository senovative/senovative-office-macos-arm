// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SenovativeUI",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "SenovativeUI",
            targets: ["SenovativeUI"]
        ),
    ],
    targets: [
        .target(
            name: "SenovativeUI"
        ),
        .testTarget(
            name: "SenovativeUITests",
            dependencies: ["SenovativeUI"]
        ),
    ]
)
