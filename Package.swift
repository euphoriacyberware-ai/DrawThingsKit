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
        .package(url: "https://github.com/euphoriacyberware-ai/DT-gRPC-Swift-Client", from: "1.2.0"),
    ],
    targets: [
        .target(
            name: "DrawThingsKit",
            dependencies: [
                .product(name: "DrawThingsClient", package: "DT-gRPC-Swift-Client"),
            ]
        ),
        .testTarget(
            name: "DrawThingsKitTests",
            dependencies: ["DrawThingsKit"]
        ),
    ]
)
