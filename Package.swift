// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FastRepo",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "FastRepo",
            path: "Sources/FastRepo"
        )
    ]
)
