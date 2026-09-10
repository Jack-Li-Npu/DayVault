// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DayVaultCore",
    defaultLocalization: "en",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "DayVaultCore", targets: ["DayVaultCore"]),
    ],
    targets: [
        .target(name: "DayVaultCore"),
        .testTarget(name: "DayVaultCoreTests", dependencies: ["DayVaultCore"]),
    ]
)

