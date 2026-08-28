// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "where-ive-been",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "where-ive-been", targets: ["WhereIveBeen"])
    ],
    targets: [
        .executableTarget(
            name: "WhereIveBeen",
            path: "Sources/where-ive-been",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "WhereIveBeenTests",
            dependencies: ["WhereIveBeen"],
            path: "Tests/where-ive-been-tests"
        )
    ]
)
