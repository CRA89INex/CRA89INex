// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "IntentionCore",
    defaultLocalization: "de",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "IntentionCore",
            targets: ["IntentionCore"]
        )
    ],
    targets: [
        .target(
            name: "IntentionCore",
            path: "Sources/IntentionCore"
        ),
        .testTarget(
            name: "IntentionCoreTests",
            dependencies: ["IntentionCore"],
            path: "Tests/IntentionCoreTests"
        )
    ]
)
