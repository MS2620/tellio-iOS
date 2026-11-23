// swift-tools-version: 6.0

import PackageDescription

/// The shared Core, Services and Shared code comes straight from the Apple TV app
/// (the Vendor/tellio submodule), so fixes there reach iOS when the submodule is bumped.
let shared = "Vendor/tellio"

let package = Package(
    name: "Tellio",
    platforms: [
        // Liquid Glass needs iOS 26.
        .iOS("26.0"),
    ],
    products: [
        // xtool builds the app from the package's single library product.
        .library(name: "Tellio", targets: ["Tellio"]),
    ],
    dependencies: [
        .package(url: "https://github.com/getsentry/sentry-cocoa", from: "9.0.0"),
        // The Apple TV app's player engine (FFmpeg-based: MKV, HEVC, surround audio).
        .package(url: "https://github.com/superuser404notfound/AetherEngine", from: "7.66.1"),
    ],
    targets: [
        .target(
            name: "Tellio",
            dependencies: [
                // The dynamic build: xtool embeds and signs it properly (the static one fails to sign).
                .product(name: "Sentry-Dynamic", package: "sentry-cocoa"),
                .product(name: "AetherEngine", package: "AetherEngine"),
            ],
            path: ".",
            exclude: [
                // Apple TV home-screen only; Shims/TopShelfPublisher.swift stands in for it.
                "\(shared)/Sources/Core/TopShelfPublisher.swift",
                // Apple TV-only parts of the repo. SwiftPM scans the whole target folder for
                // resources, so these would otherwise be picked up (e.g. the tvOS icon catalog).
                "\(shared)/Resources",
                "\(shared)/TopShelf",
                "\(shared)/Sources/Player",
                "\(shared)/server",
                // Build output: the last built app holds the engine's resource files, which
                // would otherwise be read back in as this target's resources.
                "xtool",
            ],
            sources: [
                "\(shared)/Sources/Core",
                "\(shared)/Sources/Services",
                "\(shared)/Shared",
                "Shims",
                "Sources/App",
            ],
            swiftSettings: [
                // Same language mode as the Apple TV app.
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
