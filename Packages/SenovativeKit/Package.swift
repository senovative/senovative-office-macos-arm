// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SenovativeKit",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "SenovativeKit",
            targets: ["SenovativeKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", .upToNextMajor(from: "0.9.0"))
    ],
    targets: [
        .target(
            name: "SenovativeKit",
            dependencies: ["ZIPFoundation"]
        ),
        .testTarget(
            name: "SenovativeKitTests",
            dependencies: ["SenovativeKit"],
            resources: [
                .copy("Fixtures"),
            ]
        ),
    ]
)
