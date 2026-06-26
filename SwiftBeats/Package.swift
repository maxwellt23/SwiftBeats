// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SwiftBeats",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .library(name: "SwiftBeats", targets: ["SwiftBeats"]),
        .executable(name: "SwiftBeatsDemo", targets: ["SwiftBeatsDemo"])
    ],
    targets: [
        .target(
            name: "SwiftBeats",
            path: "Sources/SwiftBeats"
        ),
        .executableTarget(
            name: "SwiftBeatsDemo",
            dependencies: ["SwiftBeats"],
            path: "Sources/SwiftBeatsDemo"
        ),
        .testTarget(
            name: "SwiftBeatsTests",
            dependencies: ["SwiftBeats"],
            path: "Tests/SwiftBeatsTests"
        )
    ]
)
