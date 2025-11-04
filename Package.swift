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
            url: "https://github.com/pcccccc/GMObjC/releases/download/1.0.5/openssl.xcframework.zip",
            checksum: "c256e92cdadeba038f070229b595b7808a620165324587ecd2437f2dffff8bc7"
        ),
        .binaryTarget(
            name: "GMObjC",
            url: "https://github.com/pcccccc/GMObjC/releases/download/1.0.5/GMObjC.xcframework.zip",
            checksum: "56e04a65c4d7a94ac29033f7b1e51d1298cbecf6950cbe064af7f51b84521a20"
        )
    ]
)
