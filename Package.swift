// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "state-kit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "StateKit",
            targets: ["StateKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.58.2"),
        .package(url: "https://github.com/pointfreeco/swift-clocks.git", from: "1.0.6"),
        .package(url: "https://github.com/Moroverse/shared-testing.git", from: "0.2.1")
    ],
    targets: [
        .target(
            name: "StateKit",
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "StateKitTests",
            dependencies: [
                .product(name: "Clocks", package: "swift-clocks"),
                .product(name: "SharedTesting", package: "shared-testing"),
                "StateKit"
            ],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        )
    ]
)
