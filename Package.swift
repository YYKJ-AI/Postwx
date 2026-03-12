// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Postwx",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Postwx",
            path: "Sources/Postwx",
            exclude: ["Info.plist"]
        )
    ]
)
