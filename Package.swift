// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "GMObjC",
    platforms: [.iOS(.v12), .macOS(.v10_13), .tvOS(.v12)],
    products: [
        .library(name: "GMObjC", targets: ["GMObjC", "openssl"]),
    ],
    dependencies: [],
    targets: [
        .binaryTarget(
            name: "openssl",
            url: "https://github.com/pcccccc/GMObjC/releases/download/1.0.9/openssl.xcframework.zip",
            checksum: "74bd5bd53fa836e7d2c1587b7c5deb7c5968f757ff1157487cf3e8313a62a8b1"
        ),
        .binaryTarget(
            name: "GMObjC",
            url: "https://github.com/pcccccc/GMObjC/releases/download/1.0.9/GMObjC.xcframework.zip",
            checksum: "c24626b2869af3fa9c277431328eb5cc9c1e31c3339dbb1ae93d9a95962ea540"
        )
    ]
)
