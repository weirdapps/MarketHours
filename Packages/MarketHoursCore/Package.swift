// swift-tools-version: 6.0
import PackageDescription

// Schedule logic for MarketHours, kept free of AppKit and SwiftUI so it can be
// tested with `swift test` (also on Linux) without launching the menu bar app.
let package = Package(
    name: "MarketHoursCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MarketHoursCore", targets: ["MarketHoursCore"])
    ],
    targets: [
        .target(
            name: "MarketHoursCore",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "MarketHoursCoreTests",
            dependencies: ["MarketHoursCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
