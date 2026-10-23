// swift-tools-version:5.9
import PackageDescription

/// Strict concurrency checking (the Swift 6 rules) while staying on tools 5.9.
let strictConcurrency: [SwiftSetting] = [.enableExperimentalFeature("StrictConcurrency")]

let package = Package(
    name: "Faro",
    platforms: [
        .iOS(.v15),
        // The core also runs on macOS, which is what `swift test` uses.
        .macOS(.v12),
    ],
    products: [
        /// The core: Foundation + CryptoKit, no UI.
        .library(name: "Faro", targets: ["Faro"]),
        /// The ready-made SwiftUI help screen, built on the core.
        .library(name: "FaroUI", targets: ["FaroUI"]),
    ],
    targets: [
        .target(
            name: "Faro",
            path: "Sources/Faro",
            resources: [.copy("PrivacyInfo.xcprivacy")],
            swiftSettings: strictConcurrency
        ),
        .target(
            name: "FaroUI",
            dependencies: ["Faro"],
            path: "Sources/FaroUI",
            resources: [.copy("PrivacyInfo.xcprivacy")],
            swiftSettings: strictConcurrency
        ),
        .testTarget(
            name: "FaroTests",
            dependencies: ["Faro"],
            path: "Tests/FaroTests",
            swiftSettings: strictConcurrency
        ),
    ]
)
