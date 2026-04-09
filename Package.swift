// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OpenCodeRemoteManager",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "OpenCodeRemoteManagerCore",
            targets: ["OpenCodeRemoteManagerCore"]
        ),
        .executable(
            name: "OpenCodeRemoteManagerApp",
            targets: ["OpenCodeRemoteManagerApp"]
        ),
        .executable(
            name: "OpenCodeRemoteManagerCLI",
            targets: ["OpenCodeRemoteManagerCLI"]
        ),
    ],
    targets: [
        .target(
            name: "OpenCodeRemoteManagerCore"
        ),
        .executableTarget(
            name: "OpenCodeRemoteManagerApp",
            dependencies: ["OpenCodeRemoteManagerCore"]
        ),
        .executableTarget(
            name: "OpenCodeRemoteManagerCLI",
            dependencies: ["OpenCodeRemoteManagerCore"]
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["OpenCodeRemoteManagerCore"]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: ["OpenCodeRemoteManagerApp", "OpenCodeRemoteManagerCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
