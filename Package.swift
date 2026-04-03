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
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "iTime",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
            ],
            exclude: ["Resources"]
        ),
        .testTarget(
            name: "iTimeTests",
            dependencies: ["iTime"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
