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
        ),
        .executable(
            name: "fountain-gui-demo",
            targets: ["fountain-gui-demo"]
        )
    ],
    targets: [
        .target(
            name: "FountainGUIKit",
            dependencies: []
        ),
        .executableTarget(
            name: "fountain-gui-demo",
            dependencies: ["FountainGUIKit"]
        ),
        .testTarget(
            name: "FountainGUIKitTests",
            dependencies: ["FountainGUIKit"]
        )
    ]
)
