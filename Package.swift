// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "Thresher",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "Thresher",
            targets: ["Thresher"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Thresher",
            dependencies: []),
        .testTarget(
            name: "ThresherTests",
            dependencies: ["Thresher"]),
    ]
)
