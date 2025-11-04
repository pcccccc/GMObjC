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
            url: "https://github.com/pcccccc/GMObjC/releases/download/1.0.7/openssl.xcframework.zip",
            checksum: "d320f33100d10ed6ccdf67f616801c3b405ffcf4c6d622dd5c5f9369eec0be27"
        ),
        .binaryTarget(
            name: "GMObjC",
            url: "https://github.com/pcccccc/GMObjC/releases/download/1.0.7/GMObjC.xcframework.zip",
            checksum: "3405a3ec2af06540d3911fd982600936d44b43a7a03dc24c73050cf3ab386b89"
        )
    ]
)
