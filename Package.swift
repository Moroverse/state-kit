// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "state-kit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .macCatalyst(.v17)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "StateKit",
            targets: ["StateKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-clocks.git", from: "1.0.6"),
        .package(url: "https://github.com/Moroverse/test-kit.git", from: "0.3.3")
    ],
    targets: [
        .target(
            name: "StateKit",
            dependencies: [
                .product(name: "Clocks", package: "swift-clocks")
            ]
        ),
        .testTarget(
            name: "StateKitTests",
            dependencies: [
                .product(name: "Clocks", package: "swift-clocks"),
                .product(name: "TestKit", package: "test-kit"),
                "StateKit"
            ]
        )
    ]
)
