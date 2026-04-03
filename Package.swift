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
            name: "iTime",
            exclude: ["Resources"]
        ),
        .testTarget(
            name: "iTimeTests",
            dependencies: ["iTime"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
