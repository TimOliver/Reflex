// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Reflex",
    platforms: [.iOS(.v10)],
    products: [
        .library(name: "Reflex", targets: ["Reflex"]),
    ],
    dependencies: [
        .package(url: "https://github.com/TimOliver/Echo", .branch("main")),
        .package(url: "https://github.com/TimOliver/FLEXD", .branch("main")),
    ],
    targets: [
        .target(
            name: "Reflex",
            dependencies: ["Echo", .product(name: "FLEX", package: "FLEXD")],
            path: "Reflex",
            exclude: ["Info.plist"]
        ),
        .testTarget(
            name: "ReflexTests",
            dependencies: ["Reflex"],
            path: "ReflexTests",
            exclude: ["Info.plist"]
        ),
    ]
)
