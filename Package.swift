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
        .package(
            url: "https://github.com/appinteractive/DT-gRPC-Swift-Client",
            branch: "fix/off-main-tensor-encoding"
        ),
        .package(
            url: "https://github.com/appinteractive/DrawThingsQueue",
            branch: "fix/off-main-tensor-encoding"
        ),
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
