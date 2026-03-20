// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DrawThingsKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "DrawThingsKit",
            targets: ["DrawThingsKit"]
        ),
    ],
    dependencies: [
        // Use remote URLs for release
        .package(url: "https://github.com/euphoriacyberware-ai/DT-gRPC-Swift-Client", branch: "main"),
        .package(url: "https://github.com/euphoriacyberware-ai/DrawThingsQueue", branch: "main"),
        // Use local path for development; switch to URL for releases:
        // .package(url: "https://github.com/euphoriacyberware-ai/DT-gRPC-Swift-Client.git", from: "1.2.2"),
        //.package(path: "../DT-gRPC-Swift-Client"),
        // .package(url: "https://github.com/euphoriacyberware-ai/DrawThingsQueue.git", branch: "main"),
        //.package(path: "../DrawThingsQueue"),
    ],
    targets: [
        .target(
            name: "DrawThingsKit",
            dependencies: [
                .product(name: "DrawThingsClient", package: "DT-gRPC-Swift-Client"),
                .product(name: "DrawThingsQueue", package: "DrawThingsQueue"),
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "DrawThingsKitTests",
            dependencies: ["DrawThingsKit"]
        ),
    ]
)
