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
            revision: "c25fdcda804f04bd9167dff60c418c1ce312e87a"
        ),
        .package(
            url: "https://github.com/appinteractive/DrawThingsQueue",
            revision: "2e4243d8845ae434b3c7e231c0a65c921fcba659"
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
