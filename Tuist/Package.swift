// swift-tools-version: 6.2

@preconcurrency import PackageDescription

let package = Package(
    name: "StateKitDependencies",
    dependencies: [
        .package(path: "../."),
        .package(url: "https://github.com/Moroverse/test-kit.git", from: "0.3.3")
    ]
)
