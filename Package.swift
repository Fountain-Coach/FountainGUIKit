// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FountainGUIKit",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "FountainGUIKit",
            targets: ["FountainGUIKit"]
        )
    ],
    targets: [
        .target(
            name: "FountainGUIKit",
            dependencies: []
        ),
        .testTarget(
            name: "FountainGUIKitTests",
            dependencies: ["FountainGUIKit"]
        )
    ]
)
