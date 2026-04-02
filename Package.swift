// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "iTime",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "iTime", targets: ["iTime"]),
    ],
    targets: [
        .executableTarget(
            name: "iTime"
        ),
        .testTarget(
            name: "iTimeTests",
            dependencies: ["iTime"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
