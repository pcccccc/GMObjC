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
            path: "Frameworks/openssl.xcframework"
        ),
        .binaryTarget(
            name: "GMObjC",
            path: "Frameworks/GMObjC.xcframework"
        )
    ]
)
