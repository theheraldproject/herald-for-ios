// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Herald",
    platforms: [
        .iOS(.v9)
    ],
    products: [
        .library(
            name: "Herald",
            targets: [
                "Herald"
            ]
        )
    ],
    targets: [
        .target(
            name: "Herald",
            path: "Herald/Herald"
        ),
        .testTarget(
            name: "HeraldTests",
            dependencies: [
                "Herald"
            ],
            path: "Herald/HeraldTests"
        )
    ],
    swiftLanguageVersions: [
        .v5
    ]
)
