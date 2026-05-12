// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "icloud-cli",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ICloudCLICore", targets: ["ICloudCLICore"]),
        .executable(name: "icloud-cli", targets: ["icloud-cli"]),
    ],
    targets: [
        .target(name: "ICloudCLICore"),
        .executableTarget(
            name: "icloud-cli",
            dependencies: ["ICloudCLICore"]
        ),
        .testTarget(
            name: "ICloudCLICoreTests",
            dependencies: ["ICloudCLICore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
