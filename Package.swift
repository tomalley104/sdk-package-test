// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PlaySDKPackage",
    platforms: [.iOS(.v16), .macCatalyst(.v16),],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "PlaySDKPackage",
            targets: ["PlaySDKPackage"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "PlaySDKPackage",
            dependencies: ["PlaySDKBinary"]
        ),
        .binaryTarget(name: "PlaySDKBinary", path: "./PlaySDK.xcframework"),
    ]
)
