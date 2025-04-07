// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "shared-foundation",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SharedFoundation",
            targets: ["SharedFoundation"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.58.2"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.3"),
        .package(url: "https://github.com/pointfreeco/swift-clocks.git", from: "1.0.6"),
        .package(url: "https://github.com/Moroverse/shared-testing.git", from: "0.2.0")
    ],
    targets: [
        .target(
            name: "SharedFoundation",
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "SharedFoundationTests",
            dependencies: [
                .product(name: "Clocks", package: "swift-clocks"),
                .product(name: "SharedTesting", package: "shared-testing"),
                "SharedFoundation"
            ],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        )
    ]
)
