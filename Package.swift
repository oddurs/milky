// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Milky",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "MilkyCore", targets: ["MilkyCore"]),
        .library(name: "MilkyStorage", targets: ["MilkyStorage"]),
        .library(name: "MilkyUI", targets: ["MilkyUI"]),
        .executable(name: "milky-mac", targets: ["MilkyMac"]),
        .executable(name: "milky-tests", targets: ["MilkyTests"]),
    ],
    targets: [
        .target(name: "MilkyCore", swiftSettings: [.swiftLanguageMode(.v5)]),
        .target(name: "MilkyStorage", dependencies: ["MilkyCore"], swiftSettings: [.swiftLanguageMode(.v5)]),
        .target(name: "MilkyUI", dependencies: ["MilkyCore", "MilkyStorage"], swiftSettings: [.swiftLanguageMode(.v5)]),
        .executableTarget(name: "MilkyMac", dependencies: ["MilkyUI"], swiftSettings: [.swiftLanguageMode(.v5)]),
        // Swift Testing and XCTest both need a full Xcode install; this machine has
        // only the Command Line Tools, so the suite runs as a plain executable.
        .executableTarget(name: "MilkyTests", dependencies: ["MilkyCore", "MilkyStorage"], swiftSettings: [.swiftLanguageMode(.v5)]),
    ]
)
